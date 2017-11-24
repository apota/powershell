Add-Type -AssemblyName System.Data.OracleClient

Function OracleCredential([string] $DataSource='*') {
    if (-not $_oracleCred) { 
        if (${function:Read-ManagedCredential}) { 
            #For now just use 1 cred for all databases
            $cred = Read-ManagedCredential Database #$DataSource 
        } else { 
            $cred = Get-Credential -Message "Enter database credential for $DataSource"
        }
        Set-Variable _oracleCred $cred -Scope Global
    }
    $_oracleCred
}

Function Read-TnsServiceNames { [CmdletBinding()]
Param(
    [string[]] $Path = @("E:\oracle\product\11.2.0\client64\network\admin\tnsnames.ora"
                         "C:\oracle\product\11.2.0\client64\network\admin\tnsnames.ora")
)
    $Path | %{ 
        if (Test-Path $_) {
            Get-Content $_ |
                ?{ $_ -Match "^\w+\.\w+\.\w+\s*=" } |
                %{ $_ -replace "\s*=\s*" } 
        }
    }
}

Function New-OracleConnection { [CmdletBinding()]
Param(
    [Parameter(Mandatory)] [string] $Database,
    [PSCredential] $Credential=$NULL,
    [Switch] $UseMachineConfigCredentials
)
    $DataSource = ([System.Configuration.ConfigurationManager]::ConnectionStrings | where name -ieq $Database).connectionString
    if ($UseMachineConfigCredentials) {
        $DataSource = ([regex]"(?:User Id=[^;]+;|Password=[^;]+;|Data Source=[^;]+;)+").Match($DataSource).Value
    } else {
        $DataSource = $DataSource -replace "^.*;Data Source=([^;]*);.*$", '$1'
        Write-Verbose ("machineConfig datasource: " + $DataSource)
        if (-not $DataSource) {
            $DataSource = Read-TnsServiceNames | ?{ $_ -match $Database }
            Write-Verbose "tnsNames datasource: $DataSource"
        }
        if (-not $DataSource) {
            $DataSource = $Database
        } elseif (($DataSource | measure).Count -gt 1) {
            throw "Did not map to a single database, be more specific"
        }
        if (-not $Credential) { $Credential = OracleCredential($DataSource) }
            $DataSource = "Data Source={0};User Id={1};Password={2};Integrated Security=no" -f @(
                $DataSource,$Credential.GetNetworkCredential().UserName,$Credential.GetNetworkCredential().Password
            )
    }
    $connection = New-Object System.Data.OracleClient.OracleConnection($DataSource)
    $connection.Open()
    $connection
}

Function New-OracleCommand{ [CmdletBinding(DefaultParameterSetName="fromPipe")]  
Param(
    [Parameter(ParameterSetName="justCon",Mandatory,Position=0)]
    [Parameter(ParameterSetName="fromPipe",ValueFromPipeline)]
    [Parameter(ParameterSetName="withCmd",Mandatory,Position=1)]
    [System.Data.OracleClient.OracleConnection]
    $Connection
    ,
    [Parameter(ParameterSetName="fromPipe",Position=0)]
    [Parameter(ParameterSetName="withCmd",Mandatory,Position=0)]
    [string]
    $CommandText
    ,
    [hashtable]
    $Parameters
)
    $cmd = $Connection.CreateCommand()
    if ($CommandText) {
        $cmd.CommandText = $CommandText
    }
    if ($Parameters) {
        foreach($Key in $Parameters.Keys) {
            $cmd.Parameters.Add( $Key, $Parameters[$Key] ) | Out-Null
        }
    }
    $cmd.CommandTimeout = 120
    $cmd
}

Function Invoke-OracleCommand{ [CmdletBinding(DefaultParameterSetName="withCmd")]  
Param(
    [Parameter(ParameterSetName="fromPipe",ValueFromPipeline)]
    [Parameter(ParameterSetName="withCmd",Mandatory,Position=1)]
    [System.Data.OracleClient.OracleConnection]
    $Connection
    ,
    [Parameter(ParameterSetName="fromPipe",Position=0)]
    [Parameter(ParameterSetName="withCmd",Mandatory,Position=0)]
    [string]
    $CommandText
    ,
    [hashtable]
    $Parameters
    ,
    [switch]
    $NonQuery
)
    $cmd = New-OracleCommand -CommandText $CommandText -Connection $Connection -Parameters $Parameters
    if ($NonQuery) {
        $cmd.ExecuteNonQuery()
    } else {
        $cmd | Out-Reader
    }
    $cmd.Dispose() | Out-Null
}


Function Invoke-OracleProcedure{ [CmdletBinding(DefaultParameterSetName="withCmd")]  
Param(
    [Parameter(ParameterSetName="fromPipe",ValueFromPipeline)]
    [Parameter(ParameterSetName="withCmd",Mandatory,Position=1)]
    [System.Data.OracleClient.OracleConnection]
    $Connection
    ,
    [Parameter(ParameterSetName="fromPipe",Position=0)]
    [Parameter(ParameterSetName="withCmd",Mandatory,Position=0)]
    [string]
    $Procedure
    ,
    [hashtable]
    $Parameters
)
    $cmd = New-OracleCommand -CommandText $Procedure -Connection $Connection -Parameters $Parameters
    $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
    $cmd.ExecuteNonQuery()
    $cmd.Dispose() | Out-Null
}

Function Out-Reader { [CmdletBinding()]
Param(
    [Parameter(Mandatory,ValueFromPipeline)]  $Command
)
    try {
        $reader = $Command.ExecuteReader()
    } Catch {
        Write-Warning ($_.Exception.InnerException | Format-List * -force | Out-String)
        Throw $_.Exception
    }
    $cols = @(0 .. ($reader.FieldCount-1))
    $names = @($cols|%{ $reader.GetName($_) })
    while ($reader.Read()) { 
        $row = New-Object PSObject
        $cols|%{ $row | Add-Member @{ $names[$_] = $reader.GetValue($_) } }
        $row
    }
}

#Export-ModuleMember -Function * -Alias *
