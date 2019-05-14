$phone = $args[0]
$phone -match '(?<first3>\d\d\d)(-)?(?<mid3>\d\d\d)(-)?(?<last4>\d\d\d\d)'  #making the phone delimiter - optional

#Normalize the phone number back to having -
$phone = "{0}-{1}-{2}" -f $Matches.first3, $Matches.mid3, $Matches.last4

$surl= "https://theylookup.com/{0}-{1}.html" -f $Matches.first3, $Matches.mid3
$anchorNextId = "{0}-{1}_next" -f $Matches.first3, $Matches.mid3
$pattern = '<td class=" ">{0}</td><td class=" ">(?<phoneOwner>(.)+)</td>' -f $phone

#invoke IE
$ie = new-object -com "InternetExplorer.Application"
$ie.visible = $false
$ie.navigate($surl)
do {sleep 1} until (-not ($ie.Busy))

#Play w/ the dom
$doc = $ie.Document;

while($doc -ne $null) {
 
    if ($doc.body.innerHTML.IndexOf($phone) -gt 0) {
       $doc.body.innerHTML -match $pattern
       Write-Host $Matches.phoneOwner
       break
    }

    For ($i =0; $i -lt $doc.anchors.length; $i++) {
        if ($doc.anchors[$i].id -eq $anchorNextId) {
            $doc.anchors[$i].click();
            $doc = $ie.Document
            break;
        }
    }
}

#If you don't to this, you will have 'N' runaway IE instances sucking up your RAM and this script will eventually stop working.
$ie.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($ie) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()