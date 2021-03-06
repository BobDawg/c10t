$CONVERT="convert"
$C10T="c10t.exe"
$C10T_OPTS=""
$C10T_OUT="c10t.out.txt"

$TILE_SIZES="4096", "2048", "1024", "512", "256", "128"
$SCALE = @{"4096"="6.25%"; "2048"="12.5%"; "1024"="25%"; "512"="50%"; "256"="100%"; "128"="200%"}
$ZOOM  = @{"4096"="0"; "2048"="1"; "1024"="2"; "512"="3"; "256"="4"; "128"="5"}


$FACTOR=16

$current= [IO.Directory]::GetCurrentDirectory()
$world=$args[0]
$target=$args[1]
$tiles="tiles"
$hostn=""

$C10T_OPTS="$C10T_OPTS -w $world"

if ( !($world) -or !(test-path $world -pathtype container) )
{
  write-host "Directory does not exist: $world";
  return 1
}
if ((!($C10T -match ".exe$")) -or (!(test-path $C10T -pathtype leaf)) )
{
  write-host "Not an executable: $C10T"
  return 1
}

if(!(test-path $target -pathtype container)){new-item -type directory -path $target}
if(!(test-path "$target\$tiles" -pathtype container)){new-item -type directory -path "$target\$tiles"}

set-content -Path $target/index.html -Value @"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta name="viewport" content="initial-scale=1.0, user-scalable=no" />
    <script type="text/javascript" src="http://maps.google.com/maps/api/js?sensor=false"></script>
    <script type="text/javascript">
      function extend(t , o) {
        for (k in o) { if (o[k] != null) { t[k] = o[k]; } }
        return t;
      }
      
      function keys(o) {
        var a = [];
        for (m in modes) { a[a.length] = m; };
        return a;
      }
      
      // The maximum width/height of the grid in regions (must be a power of two)
      var GRID_WIDTH_IN_REGIONS = 4096;
      // Map from a GRID_WIDTH_IN_REGIONS x GRID_WIDTH_IN_REGIONS square to Lat/Long (0, 0),(-90, 90)
      var SCALE_FACTOR = 90.0 / GRID_WIDTH_IN_REGIONS;
      
      // Override the default Mercator projection with Euclidean projection
      // (insert oblig. Flatland reference here)
      function EuclideanProjection() {};
      
      EuclideanProjection.prototype.fromLatLngToPoint = function(latLng, opt_point) {
        var point = opt_point || new google.maps.Point(0, 0);
        point.x = latLng.lng() / SCALE_FACTOR;
        point.y = latLng.lat() / SCALE_FACTOR;
        return point;
      };
      
      EuclideanProjection.prototype.fromPointToLatLng = function(point) {
        var lng = point.x * SCALE_FACTOR;
        var lat = point.y * SCALE_FACTOR;
        return new google.maps.LatLng(lat, lng, true);
      };
      
      function new_map_type(m, o, ob) {
        return extend(
          {
            getTileUrl: function(c, z) {
                return o.host + m + "." + c.x + "." + c.y + "." + z + ".png";
            },
            isPng: true,
            name : "none",
            alt : "none",
            minZoom: 0, maxZoom: 5,
            tileSize: new google.maps.Size(256, 256)
          },
          ob
        );
      }
      
      function initialize(id, opt, modes) {
        var element = document.getElementById(id);
        
        opt = extend(opt, {
          mapTypeControlOptions: {
            mapTypeIds: keys(modes),
            style: google.maps.MapTypeControlStyle.DROPDOWN_MENU}});
        
        var map = new google.maps.Map(element, opt);

        var firstMode = null;
        
        for (m in modes) {
          var imt  = new google.maps.ImageMapType(new_map_type(m, opt, modes[m]));
          imt.projection = new EuclideanProjection();
          
          // Now attach the grid map type to the map's registry
          map.mapTypes.set(m, imt);
          if (firstMode == null) firstMode = m;
        }
        
        map.setMapTypeId(firstMode);

        var globaldata = modes[firstMode].data;
        
        {
          var world = globaldata.world;
          var center = new google.maps.Point(world["cx"] / $FACTOR, world["cy"] / $FACTOR);
          var latlng = EuclideanProjection.prototype.fromPointToLatLng(center)
          map.setCenter(latlng);
          map.setZoom(0);
        }
        
        for (var i = 0; i < globaldata.markers.length; i++)
        {
          var m = globaldata.markers[i];
          var point = new google.maps.Point(m.x / $FACTOR, m.y / $FACTOR);
          var latlng = EuclideanProjection.prototype.fromPointToLatLng(point)
          
          new google.maps.Marker({
              position: latlng, 
              map: map, 
              title: m.text
          });
        }
        
        if (window.attachEvent) {
          window.attachEvent("onresize", function() {this.map.onResize()} );
        } else {
          window.addEventListener("resize", function() {this.map.onResize()} , false);
        }
      }
    </script>
    
    <!-- Make the document body take up the full screen -->
    <style type="text/css">
        v\:* {behavior:url(#default#VML);}
        html, body {width: 100%; height: 100%}
        body {margin-top: 0px; margin-right: 0px; margin-left: 0px; margin-bottom: 0px}
    </style>
    
    <script type="text/javascript" src="options.js"></script>
  </head>
  <body onload="initialize('map_canvas', options, modes)">
    <div id="map_canvas" style="width: 100%; height: 100%;"></div>
  </body>
</html>
"@
write-host "NOTE: if something goes wrong, check out $C10T_OUT"

write-host "" > $C10T_OUT
function generate 
{
    Param ($x_opts, $name, $pixelsplit, $zoom, $scale)
    
    # generate a set of split files
    $src="$target\$tiles\$name.`%d.`%d.$zoom.png"
    write-host "$C10T $C10T_OPTS $x_opts --pixelsplit=$pixelsplit -o $src --write-json=$target\$name.json"
    
    "$C10T $C10T_OPTS $x_opts --pixelsplit=$pixelsplit -o $src --write-json=`"$target\$name.json`" "
    invoke-expression "$C10T $C10T_OPTS $x_opts --pixelsplit=$pixelsplit -o $src --write-json=`"$target\$name.json`" "
    
    # convert the files to the appropriate sizes
     
    foreach ($file in Get-ChildItem "$target\$tiles\$name.*.*.$zoom.png")
    {
        $tg=$file.FullName
        write-host "$CONVERT $file -scale $scale $tg"
        invoke-expression "$CONVERT $file -scale $scale $file"
    }    
      
    write-host "done!"
    Get-ChildItem "$target\$tiles\$name.*.*.$zoom.png"
}

echo 1
foreach ($t in $TILE_SIZES)
{
    $z=$ZOOM.Get_Item("$t")
    $s=$SCALE.Get_Item("$t")
      
    generate -x_opts " " -name "day" -pixelsplit $t -zoom $z -scale $s
    generate -x_opts "-n" -name "night" -pixelsplit $t -zoom $z -scale $s
}    

set-content $target\options.js @"
var options = {
  host: "$hostn$tiles/",
  scaleControl: false,
  navigationControl: true,
  streetViewControl: false,
  noClear: false,
  backgroundColor: "#000000",
  isPng: true,
}

var modes = {
  'day': { name: "Day", alt: "Day Mode", data: $(cat $target/day.json)},
  'night': { name: "Night", alt: "Night Mode", data: $(cat $target/night.json)},
}
"@
