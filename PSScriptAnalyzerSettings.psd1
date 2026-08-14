# PSScriptAnalyzer configuration for this repository.
#
# Used by .github/workflows/build.yml and can be used locally:
#     Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
@{
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # Chocolatey lifecycle scripts are executed by the package manager, which
        # captures the console stream and shows it to the user. Write-Host is the
        # idiomatic way to report progress from an install/uninstall hook, and the
        # build scripts in build/ are interactive console tools as well.
        'PSAvoidUsingWriteHost',

        # build/set-version.ps1 declares -BumpMajor/-BumpMinor/-BumpPatch purely to
        # select a parameter set; the value is read via $PSCmdlet.ParameterSetName,
        # which the analyzer cannot follow.
        'PSReviewUnusedParameter'
    )
}
