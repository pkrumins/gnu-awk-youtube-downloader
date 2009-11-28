This is a YouTube video downloader written in GNU Awk. It works well but
please don't take it too seriously. It's a proof of concept code, written to
see what can be done with GNU Awk's networking interface.

It was written by Peteris Krumins (peter@catonmat.net).
His blog is at http://www.catonmat.net  --  good coders code, great reuse.

The code is licensed under the MIT license.

The code was written as a part of the article "Downloading YouTube Videos with
GNU Awk" on my website. The whole article can be read at:

    http://www.catonmat.net/blog/downloading-youtube-videos-with-gawk/

------------------------------------------------------------------------------

Table of contents:

    [1] Why did I write this program?
    [2] How to use it?


[1]-Why-did-I-write-this-program?---------------------------------------------

One day I found out that the GNU implementation of Awk had added networking
support to Awk via a special filename that looks like this:
"/inet/protocol/localport/hostname/remoteport". 

Since I love to explore obscure things and interesting language features, this
got me curious if I could write a YouTube downloader in Awk. This program is
the result of it.

The most challening parts in this project were:

    1) How to do HTTP redirection?
    I had to write a tiny HTTP protocol parser in Awk.
    (see get_headers function)

    2) How to do binary I/O?
    Awk is not meant for binary I/O. It turned out I had to choose a random
    character as the RS separator.
    (see save_file function)


[2]-How-to-use-the-program?---------------------------------------------------

Specify the list of YouTube URLs as command arguments to get_youtube_vids.awk:

    $ gawk -f get_youtube_vids.awk http://www.youtube.com/watch?v=ID1> [...]

This will download all the videos specified on the command line.

You can also specify just the YouTube video IDs:

    $ gawk -f get_youtube_vids.awk ID1 ID2 ID3 ...


------------------------------------------------------------------------------

Happy downloading!


Sincerely,
Peteris Krumins
http://www.catonmat.net

