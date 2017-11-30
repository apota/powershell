<#
   
   Use this utility prior to importing data into live tables from staging tables. It will generate CSV files 
   for new rows being added, old rows being removed and column level changes for both the tables. Examining 
   these files will help decide if it is ok to "go live" with the staged data. 

   Usage
   -----
   
   ./Differ.ps1 -Stage DisplayAdds -InputFile ./my.json -OutputDir ./mydir
   ./Differ.ps1 -Stage DisplayDeletes -InputFile ./my.json -OutputDir ./mydir
   ./Differ.ps1 -Stage DisplayChanges -InputFile ./my.json -OutputDir ./mydir


   Sample JSON input file
   ----------------------
   Compare col1 and col2 using key1 and key2 as the join columns
   
   {
  	"JoinColumns": "key1,key2",
  	"CompareColumns": "col1,col2",
  	"SourceSchema": "schema1",
  	"TargetSchema": "schema1",
  	"SourceTable": "tableA",
  	"TargetTable": "tableB",
  	"SourceWhereClause": "",
  	"TargetWhereClause": "",
  	"ExcludedCompareColumns": ""
  }

   Compare ALL columns EXCEPT column col3 using key1 and key2 as the join columns

   {
    "JoinColumns": "key1,key2",
    "CompareColumns": "*",
    "SourceSchema": "schema1",
    "TargetSchema": "schema1",
    "SourceTable": "tableA",
    "TargetTable": "tableB",
    "SourceWhereClause": "",
    "TargetWhereClause": "",
    "ExcludedCompareColumns": "col3"
  }


  Configuring DB entries 
  ----------------------

  Locate the machine.config on ur machine: %windir%\Microsoft.NET\Framework64\[version]\config\machine.config 

  Under the 
    <connectionStrings>

  section

  add your DB entry.

    <!-- General connections -->
    <add name="db" connectionString="User Id=db;Password=password;Data Source=db.myco.com;Connection Lifetime=300;Max Pool Size=10;Min Pool Size=0;Validate Connection=true;Enlist=false;Connection Timeout=60;HA Events=true;" providerName="Oracle.DataAccess.Client" />


#>

Param 
( 
    [Parameter(Mandatory=$True)]
    [ValidateSet("DisplayAdds","DisplayDeletes", "DisplayChanges")]
    [string] $Step,
    [Parameter(Mandatory=$True)]
    [string] $InputFile,
    [Parameter(Mandatory=$True)]
    [string] $OutputDir
)


Import-Module -Name .\Modules\OracleClient;
Import-Module -Name .\Modules\DifferCore;

#################################################
#      Get to work
#################################################

Function ValidateOutputFiles([string] $addedFile, [string] $removedFile, [string] $changeFile) {

    if (-not (Test-Path $OutputDir))  {
        New-Item $OutputDir -ItemType "directory"
    } 

    if ((Test-Path $OutputDir + $addedFile)) {
        Remove-Item $OutputDir + $addedFile -Force
    }
    if ((Test-Path $OutputDir + $changeFile)) {
        Remove-Item $OutputDir + $changeFile -Force
    }
    if ((Test-Path $OutputDir + $removedFile)) {
        Remove-Item $OutputDir + $removedFile -Force
    }

   New-Item $OutputDir + $addedFile -ItemType "file"
   New-Item $OutputDir + $changeFile -ItemType "file"
   New-Item $OutputDir + $removedFile -ItemType "file"

}


Function Execute() { 

    $dbconn = GetDBConnection "oracle" "va2.prd"

    $input = Get-Content $InputFile | ConvertFrom-Json   

    $output = CalculateDiffSql $dbconn $input

    ValidateOutputFiles $output.AddedCSVFile $output.RemovedCSVFile $output.ChangeCSVFile 

     $addedOutputFile = $OutputDir + $output.AddedCSVFile
     $removedOutputFile = $OutputDir + $output.RemovedCSVFile
     $changeOutputFile = $OutputDir + $output.ChangeCSVFile


    if ($Step -eq "DisplayAdds") {

       Get-QueryData $output.AddedSql $dbconn | Export-Csv -Path $addedOutputFile
       Import-Csv -Path $addedOutputFile | Out-GridView -PassThru

    } elseif ($Step -eq "DisplayDeletes") {

       Get-QueryData $output.RemovedSql $dbconn | Export-Csv -Path $removedOutputFile
       Import-Csv -Path $removedOutputFile | Out-GridView -PassThru

    } elseif ($Step -eq "DisplayChanges") {
      
       Get-QueryData $output.ChangeSql $dbconn | Export-Csv -Path $changeOutputFile
       Import-Csv -Path $changeOutputFile | Out-GridView -PassThru

    } elseif ($Step -eq "Generate_All_Without_Display") {

       Get-QueryData $output.AddedSql $dbconn | Export-Csv -Path $addedOutputFile
       Get-QueryData $output.RemovedSql $dbconn | Export-Csv -Path $removedOutputFile
       Get-QueryData $output.ChangeSql $dbconn | Export-Csv -Path $changeOutputFile
      
    }


 }



#################################################
#      Act on script params...
#################################################

Execute $Step
