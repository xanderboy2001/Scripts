function Test-FileHash {
    <#
    .SYNOPSIS
        Tests whether a file's cryptographic hash matches an expected value.

    .DESCRIPTION
        Computes a file hash using the specified algorithm (default SHA256) and compares
        it to the expected hash value, either provided directly or read from a checksum file.

    .PARAMETER Path
        The path to the file whose hash you want to verify. Supports pipeline input.

    .PARAMETER ExpectedHash
        The expected checksum value to compare against.

    .PARAMETER Algorithm
        The hashing algorithm to use. Defaults to SHA256

    .PARAMETER ThrowOnMismatch
        If set, the function will throw a terminating error when the file's hash does not match.

    .EXAMPLE
        Test-FileHash -Path 'file.iso' -ExpectedHash 'ABC123...' -Algorithm SHA512

    .EXAMPLE
        'file1.txt', 'file2.txt' | Test-FileHash -ExpectedHash 'ABC123...'

    .NOTES
        Author: Alex Christian
    #>

    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [Alias('FullName')]
        [string]$Path,

        [Parameter(Mandatory, Position = 1)]
        [string]$ExpectedHash,

        [Parameter(Position = 2)]
        [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5')]
        [string]$Algorithm = 'SHA256',

        [switch]$ThrowOnMismatch
    )

    begin {
        # Normalize ExpectedHash
        $ExpectedHash = $ExpectedHash.ToUpper()
    }

    process {
        if (-not (Test-Path -LiteralPath $Path)) {
            Write-Error "File not found: $Path"
            return
        }

        try {
            $actual = (Get-FileHash -Algorithm $Algorithm -LiteralPath $Path).Hash
        }
        catch {
            Write-Error "Failed to compute hash for '$Path' using algorithm '$Algorithm': $_"
            return
        }

        $isMatch = $actual -eq $ExpectedHash

        if (-not $isMatch -and $ThrowOnMismatch) {
            throw "Hash mismatch for '$Path'. Expected $ExpectedHash"
        }

        [PSCustomObject]@{
            Path         = (Resolve-Path $Path).Path
            Algorithm    = $Algorithm
            ExpectedHash = $ExpectedHash
            ActualHash   = $actual
            Matches      = $isMatch
        }
    }
}