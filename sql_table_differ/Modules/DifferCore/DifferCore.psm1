Add-Type -AssemblyName System.Data.OracleClient



<#
    SQL diff
#>

Function CalculateDiffSql([System.Data.OracleClient.OracleConnection] $connection, [PSCustomObject] $config) {

    $Comma = ","
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

      $table = Get-QueryData $metadataSql $connection
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

    $AddedSql = "select {0} from ({1} minus {2})" -f $JoinColumns, $TargetSql,$SourceSql
    $RemovedSql = "select {0} from ({1} minus {2})" -f $JoinColumns, $TargetSql,$SourceSql


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

 
    $ChangeSql = "with a as ({0}), b as ({1}) " -f $SourceSql, $TargetSql


    $CompareColumnsArray = $CompareColumns.Split(",");

    For ($i = 0; $i -lt $CompareColumnsArray.Count; ++$i) {
        if ($i -ne 0) {
          $ChangeSql += " union "
        }
        $ChangeSql += " select {0} '{1}' as attribute, '' || a.{1} thisval, '' || b.{1} thatval from b {2} where a.{1} != b.{1}" -f $SelectFrag, $CompareColumnsArray[$i],$JoinSql
    } 


    $output = New-Object System.Object
    $output | Add-Member -type NoteProperty -name ChangeSql -value $ChangeSql
    $output | Add-Member -type NoteProperty -name AddedSql -value $AddedSql
    $output | Add-Member -type NoteProperty -name RemovedSql -value $RemovedSql
    $output | Add-Member -type NoteProperty -name ChangeCSVFile -value "\changes.csv"
    $output | Add-Member -type NoteProperty -name AddedCSVFile -value "\added.csv"
    $output | Add-Member -type NoteProperty -name RemovedCSVFile -value "\removed.csv"
    
    $output
}

Export-ModuleMember -Function * -Alias *