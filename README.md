#Initial version of a deluge-to-rtorrent script#  

Dependencies:  

1. Rtorrent with scgi socket enabled
2. Pyrocore: https://pyrocore.readthedocs.io/en/latest/overview.html
3. Deluge 2.X (tested on 2.0.4dev8 on Debian Stretch). 1.X should also work but it's currently untested.
4. Execute plugin installed and enabled: https://dev.deluge-torrent.org/wiki/Plugins/Execute


The script can also be ran manually. Sample syntax:

move_to_rtorrent.sh omi8op96vamnwufh2o16ln9swg5qojf61jqvqlhn "My Torrent Name" "/path/to/my/torrent/top/folder" (where omi8op96vamnwufh2o16ln9swg5qojf61jqvqlhn is the torrent ID as listed in "Details" tab in deluge)
Script tries to dynamically figure out the torrent name and torrent path. However, in deluge 1.x the console info plug-in doesn't have any field that lists the path. If you run deluge 1.X then all 3 parameters are mandatory.

Let's asume the following:

Torrent ID: omi8op96vamnwufh2o16ln9swg5qojf61jqvqlhn  
Torrent name: Mia Comes Home Again 2019.720p.BluRay.DD5.1.x264  
Torrent path: /home/downloads/movies/hd_movies  

If you run deluge 1.X then you should call the script like this:

$SCRIPT_PATH/move_to_rtorrent.sh "omi8op96vamnwufh2o16ln9swg5qojf61jqvqlhn" "Mia Comes Home Again 2019.720p.BluRay.DD5.1.x264" "/home/downloads/movies/hd_movies"

If you run deluge 2.X then this is enough:

$SCRIPT_PATH/move_to_rtorrent.sh "omi8op96vamnwufh2o16ln9swg5qojf61jqvqlhn"

Execute plug-in sends all 3 parameters anyway so this isn't an issue unless ran manually.

There is also experimental support for command timeout. If you're not sure, don't enable it.

How to use:
1. Configure rtorrent and make sure the user running the script has read/write access to rtorrent's scgi_sock
2. Configure pyrocore
3. Have deluge accessible over TCP/IP
4. Get the scripts and configure settings
git clone https://github.com/fsamareanu/deluge_to_rtorrent 
cd deluge_to_rtorrent
cp conf/settings.sh.dist conf/settings.sh
Edit settings.sh to match your environment
5. Configure Execute plugin in deluge and restart both deluge web and deluge daemon

If the script has any issues run it from command line and provide the screen output + the log mentioned at the top

Pull requests are welcome. So is _constructive_ criticism.
