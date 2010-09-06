#!/usr/bin/gawk -f
#
# 2007.07.10 v1.0 - initial release
# 2007.10.21 v1.1 - youtube changed the way it displays vids
# 2008.03.01 v1.2 - youtube changed the way it displays vids
# 2008.08.28 v1.3 - added a progress bar and removed need for --re-interval 
# 2009.08.25 v1.4 - youtube changed the way it displays vids
#
# Peteris Krumins (peter@catonmat.net)
# http://www.catonmat.net -- good coders code, great reuse
#
# Usage: gawk -f get_youtube_vids.awk <http://youtube.com/watch?v=ID1 | ID1> ...
# or just ./get_youtube_vids.awk <http://youtube.com/watch?v=ID1 | ID1>
#

BEGIN {
    if (ARGC == 1) usage();

    BINMODE = 3

    delete ARGV[0]
    print "Parsing YouTube video urls/IDs..."
    for (i in ARGV) {
        vid_id = parse_url(ARGV[i])
        if (length(vid_id) < 6) { # havent seen youtube vids with IDs < 6 chars
            print "Invalid YouTube video specified: " ARGV[i] ", not downloading!"
            continue
        }
        VIDS[i] = vid_id
    }

    for (i in VIDS) {
        print "Getting video information for video: " VIDS[i] "..."
        get_vid_info(VIDS[i], INFO)

        if (INFO["_redirected"]) {
            print "Could not get video info for video: " VIDS[i]
            continue 
        }

        if (!INFO["video_url"]) {
            print "Could not get video_url for video: " VIDS[i]
            print "Please goto my website, and submit a comment with an URL to this video, so that I can fix it!"
            print "Url: http://www.catonmat.net/blog/downloading-youtube-videos-with-gawk/"
            continue
        }
        if ("title" in INFO) {
            print "Downloading: " INFO["title"] "..."
            title = INFO["title"]
        }
        else {
            print "Could not get title for video: " VIDS[i]
            print "Trying to download " VIDS[i] " anyway"
            title = VIDS[i]
        }
        download_video(INFO["video_url"], title)
    }
}

function usage() {
    print "Downloading YouTube Videos with GNU Awk"
    print
    print "Peteris Krumins (peter@catonmat.net)"
    print "http://www.catonmat.net  --  good coders code, great reuse"
    print 
    print "Usage: gawk -f get_youtube_vids.awk <http://youtube.com/watch?v=ID1 | ID1> ..."
    print "or just ./get_youtube_vids.awk <http://youtube.com/watch?v=ID1 | ID1> ..."
    exit 1
}

#
# function parse_url
#
# takes a url or an ID of a youtube video and returns just the ID
# for example the url could be the full url: http://www.youtube.com/watch?v=ID
# or it could be www.youtube.com/watch?v=ID
# or just youtube.com/watch?v=ID or http://youtube.com/watch?v=ID
# or just the ID
#
function parse_url(url) {
    gsub(/http:\/\//, "", url)                # get rid of http:// part
    gsub(/www\./,     "", url)                # get rid of www.    part
    gsub(/youtube\.com\/watch\?v=/, "", url)  # get rid of youtube.com... part

    if ((p = index(url, "&")) > 0)      # get rid of &foo=bar&... after the ID
        url = substr(url, 1, p-1)

    return url
}

#
# function get_vid_info
#
# function takes the youtube video ID and gets the title of the video
# and the url to .flv file
#
function get_vid_info(vid_id, INFO,    InetFile, Request, HEADERS, matches, escaped_urls, fmt_urls, fmt) {
    delete INFO
    InetFile = "/inet/tcp/0/www.youtube.com/80"
    Request = "GET /watch?v=" vid_id " HTTP/1.1\r\n"
    Request = Request "Host: www.youtube.com\r\n\r\n"

    get_headers(InetFile, Request, HEADERS)
    if ("Location" in HEADERS) {
        INFO["_redirected"] = 1
        close(InetFile)
        return
    }

    expect_title = 0
    # fix this bug:
    # http://www.youtube.com/watch?v=nb1u7wMKywM
    while ((InetFile |& getline) > 0) {
        if (expect_title == 2) {
            if (match($0, /- (.+)$/, matches)) {
                INFO["title"] = matches[1]
            }
        }
        if (expect_title) {
            expect_title++;
        }
        if (match($0, /"fmt_url_map": "([^"]+)"/, matches)) {
            escaped_urls = url_unescape(matches[1])
            deslash_urls = url_deslash(escaped_urls)
            split(deslash_urls, fmt_urls, /,?[0-9]+\|/)
            for (fmt in fmt_urls) {
                if (fmt_urls[fmt] ~ /itag=5/) {
                    # fmt number 5 is the best video
                    INFO["video_url"] = fmt_urls[fmt]
                    close(InetFile)
                    return
                }
            }
            close(InetFile)
            return
        }
        else if (match($0, /<title>/)) {
            expect_title = 1
        }
        #else if (match($0, /<title>YouTube - ([^<]+)</, matches)) {
            # lets try to get the title of the video from html tag which is
            # less likely a subject to future html design changes
        #    INFO["title"] = matches[1]
        #}
    }
    close(InetFile)
}

#
# function url_unescape
#
# given a string, it url-unescapes it.
# charactes such as %20 get converted to their ascii counterparts.
#
function url_unescape(str,    nmatches, entity, entities, seen, i) {
    nmatches = find_all_matches(str, "%[0-9A-Fa-f][0-9A-Fa-f]", entities)
    for (i = 1; i <= nmatches; i++) {
        entity = entities[i]
        if (!seen[entity]) {
            if (entity == "%26") { # special case for gsub(s, r, t), when r = '&'
                gsub(entity, "\\&", str)
            }
            else {
                gsub(entity, url_entity_unescape(entity), str)
            }
            seen[entity] = 1
        }
    }
    return str
}

#
# function url_deslash
#
# given a url that has escaped slashes \/, unescape them to just /
#
function url_deslash(str) {
    gsub(/\\\//, "/", str)
    return str
}

#
# function find_all_matches
#
# http://awk.freeshell.org/FindAllMatches
#
function find_all_matches(str, re, arr,    j, a, b) {
    j=0
    a = RSTART; b = RLENGTH   # to avoid unexpected side effects

    while (match(str, re) > 0) {
        arr[++j] = substr(str, RSTART, RLENGTH)
        str = substr(str, RSTART+RLENGTH)
    }
    RSTART = a; RLENGTH = b
    return j
}

#
# function url_entity_unescape
#
# given an url-escaped entity, such as %20, return its ascii counterpart.
#
function url_entity_unescape(entity) {
    sub("%", "", entity)
    return sprintf("%c", strtonum("0x" entity))
}

#
# function download_video
#
# takes the url to video and saves the movie to current directory using
# santized video title as filename
#
function download_video(url, title,    filename, InetFile, Request, Loop, HEADERS, FOO) {
    title = sanitize_title(title)
    filename = create_filename(title)

    parse_location(url, FOO)
    InetFile = FOO["InetFile"]
    Request  = "GET " FOO["Request"] " HTTP/1.1\r\n"
    Request  = Request "Host: " FOO["Host"] "\r\n\r\n"

    Loop = 0 # make sure we do not get caught in Location: loop
    do {     # we can get more than one redirect, follow them all
        get_headers(InetFile, Request, HEADERS)
        if ("Location" in HEADERS) { # we got redirected, let's follow the link
            close(InetFile)
            parse_location(HEADERS["Location"], FOO)
            InetFile = FOO["InetFile"]
            Request  = "GET " FOO["Request"] " HTTP/1.1\r\n"
            Request  = Request "Host: " FOO["Host"] "\r\n\r\n"
            if (InetFile == "") {
                print "Downloading '" title "' failed, couldn't parse Location header!"
                return
            }
        }
        Loop++
    } while (("Location" in HEADERS) && Loop < 5)

    if (Loop == 5) {
        print "Downloading '" title "' failed, got caught in Location loop!"
        return
    }
    
    print "Saving video to file '" filename "' (size: " bytes_to_human(HEADERS["Content-Length"]) ")..."
    save_file(InetFile, filename, HEADERS)
    close(InetFile)
    print "Successfully downloaded '" title "'!"
}

#
# function sanitize_title
#
# sanitizes the video title, by removing ()'s, replacing spaces with _, etc.
# 
function sanitize_title(title) {
    gsub(/\(|\)/, "", title)
    gsub(/[^[:alnum:]-]/, "_", title)
    gsub(/_-/, "-", title)
    gsub(/-_/, "-", title)
    gsub(/_$/, "", title)
    gsub(/-$/, "", title)
    gsub(/_{2,}/, "_", title)
    gsub(/-{2,}/, "-", title)
    return title
}

#
# function create_filename
#
# given a sanitized video title, creates a nonexisting filename
#
function create_filename(title,    filename, i) {
    filename = title ".flv"
    i = 1
    while (file_exists(filename)) {
        filename = title "-" i ".flv"
        i++
    }
    return filename
}

#
# function save_file
#
# given a special network file and filename reads from network until eof
# and saves the read contents into a file named filename
#
function save_file(Inet, filename, HEADERS,    done, cl, perc, hd, hcl) {
    OLD_RS  = RS
    OLD_ORS = ORS

    ORS = ""

    # clear the file
    print "" > filename

    # here we will do a little hackery to write the downloaded data
    # to file chunk by chunk instead of downloading it all to memory
    # and then writing
    #
    # the idea is to use a regex for the record field seperator
    # everything that gets matched is stored in RT variable
    # which gets written to disk after each match
    #
    # RS = ".{1,512}" # let's read 512 byte records

    RS = "@" # I replaced the 512 block reading with something better.
             # To read blocks I had to force users to specify --re-interval,
             # which made them uncomfortable.
             # I did statistical analysis on YouTube video files and
             # I found that hex value 0x40 appears pretty often (200 bytes or so)!
             #

    cl = HEADERS["Content-Length"]
    hcl = bytes_to_human(cl)
    done = 0
    while ((Inet |& getline) > 0) {
        done += length($0 RT)
        perc = done*100/cl
        hd = bytes_to_human(done)
        printf "Done: %d/%d bytes (%d%%, %s/%s)            \r",
            done, cl, perc, bytes_to_human(done), bytes_to_human(cl)
        print $0 RT >> filename
    }
    printf "Done: %d/%d bytes (%d%%, %s/%s)            \n",
        done, cl, perc, bytes_to_human(done), bytes_to_human(cl)

    RS  = OLD_RS
    ORS = OLD_ORS
}

#
# function get_headers
#
# given a special inet file and the request saves headers in HEADERS array
# special key "_status" can be used to find HTTP response code
# issuing another getline() on inet file would start returning the contents
#
function get_headers(Inet, Request,    HEADERS, matches, OLD_RS) {
    delete HEADERS

    # save global vars
    OLD_RS=RS

    print Request |& Inet

    # get the http status response
    if (Inet |& getline > 0) {
        HEADERS["_status"] = $2
    }
    else {
        print "Failed reading from the net. Quitting!"
        exit 1
    }

    RS="\r\n"
    while ((Inet |& getline) > 0) {
        # we could have used FS=": " to split, but i could not think of a good
        # way to handle header values which contain multiple ": "
        # so i better go with a match
        if (match($0, /([^:]+): (.+)/, matches)) {
            HEADERS[matches[1]] = matches[2]
        }
        else { break }
    }
    RS=OLD_RS
}

#
# function parse_location
#
# given a Location HTTP header value the function constructs a special
# inet file and the request storing them in FOO
#
function parse_location(location, FOO) {
    # location might look like http://cache.googlevideo.com/get_video?video_id=ID
    if (match(location, /http:\/\/([^\/]+)(\/.+)/, matches)) {
        FOO["InetFile"] = "/inet/tcp/0/" matches[1] "/80"
        FOO["Host"]     = matches[1]
        FOO["Request"]  = matches[2]
    }
    else {
        FOO["InetFile"] = ""
        FOO["Host"]     = ""
        FOO["Request"]  = ""
    }
}

# function bytes_to_human
#
# given bytes, converts them to human readable format like 13.2mb
#
function bytes_to_human(bytes,    MAP, map_idx, bytes_copy) {
    MAP[0] = "b"
    MAP[1] = "kb"
    MAP[2] = "mb"
    MAP[3] = "gb"
    MAP[4] = "tb"
   
    map_idx = 0
    bytes_copy = int(bytes)
    while (bytes_copy > 1024) {
        bytes_copy /= 1024
        map_idx++
    }

    if (map_idx > 4)
        return sprintf("%d bytes", bytes, MAP[map_idx])
    else
        return sprintf("%.02f%s", bytes_copy, MAP[map_idx])
}

#
# function file_exists
#
# given a path to file, returns 1 if the file exists, or 0 if it doesn't
#
function file_exists(file,    foo) {
    if ((getline foo <file) >= 0) {
        close(file)
        return 1
    }
    return 0
}

