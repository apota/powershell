$surl= "https://theylookup.com/318-299.html"
$ie = new-object -com "InternetExplorer.Application"
$ie.visible = $true
$ie.navigate($surl)

do {sleep 1} until (-not ($ie.Busy))

$doc = $ie.Document;

while($true) {
 
    if ($doc.body.innerHTML.IndexOf("318-299-2835") -gt 0) {
       Write-Host "Found phone"
       break
    }

    For ($i =0; $i -lt $doc.anchors.length; $i++) {
        if ($doc.anchors[$i].id -eq "318-299_next") {
            $doc.anchors[$i].click();
            Write-Host "Next click"
            $doc = $ie.Document
            break;
        }
    }   
}
