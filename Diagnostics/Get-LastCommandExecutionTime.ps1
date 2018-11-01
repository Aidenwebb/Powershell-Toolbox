Function Get-LastCommandExecutionTime {
    <#
        .SYNOPSIS
            Gets the execution time of the last command used.
        .EXAMPLE
            Get-LastCommandExecutionTime

            Description
            -----------
            Gets the last execution time of the last command run.
    #>
    Process {
        (Get-History)[-1].EndExecutionTime - (Get-History)[-1].StartExecutionTime
    }
}