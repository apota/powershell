<#
   
   Use this utility prior to importing data into live tables from staging tables. It will generate CSV files 
   for new rows being added, old rows being removed and column level changes for both the tables. Examining 
   these files will help decide if it is ok to "go live" with the staged data. 

   Usage
   -----
   
   ./Differ.ps1 -Stage DisplayAdds -InputFile ./my.json
   ./Differ.ps1 -Stage DisplayDeletes -InputFile ./my.json
   ./Differ.ps1 -Stage DisplayChanges -InputFile ./my.json


   Sample JSON input file
   ----------------------

   {
	"OutputDirectoryName": "compare_dir",
	"JoinColumns": "name",
	"CompareColumns": "col1,col2",
	"SourceSchema": "schema1",
	"TargetSchema": "schema1",
	"SourceTable": "tableA",
	"TargetTable": "tableB",
	"SourceWhereClause": "",
	"TargetWhereClause": "",
	"ExcludedCompareColumns": ""
  }




#>

Param 
( 
    [Parameter(Mandatory=$True)]
    [ValidateSet("DisplayAdds","DisplayDeletes", "DisplayChanges")]
    [string] $Step,
    [Parameter(Mandatory=$True)]
    [string] $InputFile
)


Import-Module -Name .\Modules\OracleClient;


#################################################
#      vars
#################################################

Set-Variable config $null -Scope Script
$dbArgs2 = @{
    Database = "db" 
    Credential = if ($Credential) {$Credential} else {Get-Credential -Message "Enter Database Credential:"}
}

$connection = New-OracleConnection @dbArgs2

$Comma = ","
Set-Variable AddedSql $null -Scope Script
Set-Variable RemovedSql $null -Scope Script
Set-Variable ChangeSql $null -Scope Script
Set-Variable OutputPath $null -Scope Script


#################################################
#      Get to work
#################################################


Function GetAddedFile() {
  $f = $script:OutputPath
  return $f + "\added.csv"
}

Function GetRemovedFile() {
  $f = $script:OutputPath
  return $f + "\removed.csv"
}

Function GetChangesFile() {
  $f = $script:OutputPath
  return $f + "\changes.csv"
}


Function ReadInput() {
  
   $script:config = Get-Content $InputFile | ConvertFrom-Json   
   $name = $script:config.OutputDirectoryName
   $CurrDir = (Resolve-Path .\).Path
   $script:OutputPath =  "{0}\{1}" -f $CurrDir,$name
   if (-not (Test-Path $script:OutputPath))  {
        New-Item $OutputPath -ItemType "directory"
   } 

}


Function Get-QueryData([string] $cmdText) {
        $Cmd = New-OracleCommand -Connection $connection -CommandText $cmdText
        $Datatable = New-Object System.Data.DataTable
        $Reader = $Cmd.ExecuteReader()
        $Datatable.Load($Reader)
        $Cmd.Dispose() | Out-Null
        return $DataTable
}


Function Calc() {
  
    $CompareColumns = $config.CompareColumns.ToUpper()
    $JoinColumns = $config.JoinColumns.ToUpper()
    $ExcludedColumns = $config.ExcludedCompareColumns.ToUpper()
    $SourceSchema = $config.SourceSchema
    $TargetSchema = $config.TargetSchema
    $SourceTable = $config.SourceTable
    $TargetTable = $config.TargetTable
    $SourceWhereClause = $config.SourceWhereClause
    $TargetWhereClause = $config.TargetWhereClause


    $ExcludedColumnsArray  = $null
    if ($ExcludedColumns -ne $null) {
        $ExcludedColumnsArray = $ExcludedColumns.Split($Comma);
    }

    $JoinColumnsArray = $JoinColumns.Split($Comma);


    if ($CompareColumns -eq "*") {

      $CompareColumns = ""
      $metadataSql = "select * from {0}.{1} where rownum < 2" -f $SourceSchema,$SourceTable 

      $table = Get-QueryData $metadataSql
      foreach ($col in $table.Table.Columns) {

         $cn = $col.ColumnName.ToUpper()

        if ($JoinColumnsArray.Contains($cn)) {
           continue;
        }

        if ($ExcludedColumnsArray -ne $null -and !$ExcludedColumnsArray.Contains($cn)) {
            $CompareColumns += $cn + ","
        }
      }

       $CompareColumns = $CompareColumns.Substring(0, $CompareColumns.Length-1)

    } 

    $SourceSql = "select {0},{1} from {2}.{3} where {4}" -f $CompareColumns,$JoinColumns,$SourceSchema,$SourceTable,$SourceWhereClause
    $TargetSql = "select {0},{1} from {2}.{3} where {4}" -f $CompareColumns,$JoinColumns,$TargetSchema,$TargetTable,$TargetWhereClause

    $script:AddedSql = "select {0} from ({1} minus {2})" -f $JoinColumns, $TargetSql,$SourceSql
    $script:RemovedSql = "select {0} from ({1} minus {2})" -f $JoinColumns, $TargetSql,$SourceSql


    $JoinSql = "join a on "
    $SelectFrag = ""

    For ($i = 0; $i -lt $JoinColumnsArray.Count; ++$i) {

        if ($i -eq 0) {                                            
            $JoinSql += "a.{0} = b.{0}" -f $JoinColumnsArray[$i];
        } else {
            $JoinSql += " and a.{0} = b.{0}" -f $JoinColumnsArray[$i];
        } 

        $SelectFrag += "b.{0}," -f $JoinColumnsArray[$i]
    }

 
    $script:ChangeSql = "with a as ({0}), b as ({1}) " -f $SourceSql, $TargetSql


    $CompareColumnsArray = $CompareColumns.Split(",");

    For ($i = 0; $i -lt $CompareColumnsArray.Count; ++$i) {
        if ($i -ne 0) {
          $script:ChangeSql += " union "
        }
        $script:ChangeSql += " select {0} '{1}' as attribute, '' || a.{1} thisval, '' || b.{1} thatval from b {2} where a.{1} != b.{1}" -f $SelectFrag, $CompareColumnsArray[$i],$JoinSql
    } 

    #Write-Output $script:AddedSql

}


Function ShowStuff() { 

    ReadInput

    Calc

    if ($Step -eq "DisplayAdds") {
      $sql = $script:AddedSql
      $file = GetAddedFile
    } elseif ($Step -eq "DisplayDeletes") {
      $sql = $script:RemovedSql
      $file = GetRemovedFile
    } elseif ($Step -eq "DisplayChanges") {
      $sql = $script:ChangeSql
      $file = GetChangesFile
    }

    if ((Test-Path $file)) {
        Remove-Item $file -Force
    }
    New-Item $file -ItemType "file"
    Get-QueryData $sql | Export-Csv -Path $file  #Store to csv, so that you can compare later using Excel.
    Import-Csv -Path $file | Out-GridView -PassThru
 }



#################################################
#      Act on script params...
#################################################

ShowStuff $Step
