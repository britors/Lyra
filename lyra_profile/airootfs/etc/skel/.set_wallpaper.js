var allDesktops = desktops();
print (allDesktops);
for (var i=0;i<allDesktops.length;i++) {
    d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = Array("Wallpaper", "org.kde.image", "General");
    d.writeConfig("Image", "file:///usr/share/wallpapers/lyra/lyra-cosmos.svg");
}
