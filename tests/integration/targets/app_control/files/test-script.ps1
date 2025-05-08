[CmdletBinding()]
param (
    [string]
    $Value
)

@{
    language_mode = $ExecutionContext.SessionState.LanguageMode.ToString()
    ünicode = $Value
}
