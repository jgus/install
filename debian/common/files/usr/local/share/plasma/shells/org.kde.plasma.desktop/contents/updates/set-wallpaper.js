var Desktops = desktops();                                                                                                                       
for (i=0;i<Desktops.length;i++) {
        d = Desktops[i];
        d.wallpaperPlugin = "org.kde.slideshow";
        d.currentConfigGroup = Array("Wallpaper",
                                    "org.kde.slideshow",
                                    "General");
        d.writeConfig("Image", "file:///bulk/Photos/Favorites/Landscape/18-10-19-13-34-03 _DSC0193.jpg");
        d.writeConfig("SlidePaths", "/bulk/Photos/Favorites/Landscape");
}
