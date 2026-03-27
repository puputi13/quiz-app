Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Width = 10
$Height = 20
$TickMs = 50
$DropIntervalMs = 500

$PieceDefs = @{
    I = @{ Id = 1; Blocks = @(@(-1,0), @(0,0), @(1,0), @(2,0)); Rotates = $true }
    O = @{ Id = 2; Blocks = @(@(0,0), @(1,0), @(0,1), @(1,1)); Rotates = $false }
    T = @{ Id = 3; Blocks = @(@(-1,0), @(0,0), @(1,0), @(0,1)); Rotates = $true }
    S = @{ Id = 4; Blocks = @(@(0,0), @(1,0), @(-1,1), @(0,1)); Rotates = $true }
    Z = @{ Id = 5; Blocks = @(@(-1,0), @(0,0), @(0,1), @(1,1)); Rotates = $true }
    J = @{ Id = 6; Blocks = @(@(-1,0), @(0,0), @(1,0), @(1,1)); Rotates = $true }
    L = @{ Id = 7; Blocks = @(@(-1,0), @(0,0), @(1,0), @(-1,1)); Rotates = $true }
}
$PieceTypes = @('I','O','T','S','Z','J','L')
$ScoreTable = @{ 0 = 0; 1 = 100; 2 = 300; 3 = 500; 4 = 800 }

function New-EmptyRow {
    param([int]$W)
    $row = New-Object 'int[]' $W
    return $row
}

function New-Board {
    param([int]$W, [int]$H)
    $board = New-Object 'int[][]' $H
    for ($y = 0; $y -lt $H; $y++) {
        $board[$y] = New-EmptyRow -W $W
    }
    return $board
}

function New-Piece {
    param([int]$SpawnX)
    $type = $PieceTypes | Get-Random
    return [pscustomobject]@{
        Type = $type
        X = $SpawnX
        Y = 0
        Rotation = 0
        Id = $PieceDefs[$type].Id
    }
}

function Rotate-Point {
    param(
        [int]$X,
        [int]$Y,
        [int]$Times
    )
    $rx = $X
    $ry = $Y
    for ($i = 0; $i -lt $Times; $i++) {
        $tmp = $rx
        $rx = $ry
        $ry = -$tmp
    }
    return @($rx, $ry)
}

function Get-RelativeBlocks {
    param(
        [string]$Type,
        [int]$Rotation
    )
    $def = $PieceDefs[$Type]
    $blocks = @()
    $turns = (($Rotation % 4) + 4) % 4

    foreach ($b in $def.Blocks) {
        if ($def.Rotates) {
            $rot = Rotate-Point -X $b[0] -Y $b[1] -Times $turns
            $blocks += ,@($rot[0], $rot[1])
        }
        else {
            $blocks += ,@($b[0], $b[1])
        }
    }

    return $blocks
}

function Get-AbsoluteBlocks {
    param(
        $Piece,
        [int]$OffsetX = 0,
        [int]$OffsetY = 0,
        [int]$RotationDelta = 0
    )

    $blocks = @()
    $rot = $Piece.Rotation + $RotationDelta
    foreach ($rb in (Get-RelativeBlocks -Type $Piece.Type -Rotation $rot)) {
        $blocks += ,[pscustomobject]@{
            X = $Piece.X + $OffsetX + $rb[0]
            Y = $Piece.Y + $OffsetY + $rb[1]
        }
    }

    return $blocks
}

function Test-Collision {
    param(
        [int[][]]$Board,
        $Piece,
        [int]$OffsetX = 0,
        [int]$OffsetY = 0,
        [int]$RotationDelta = 0
    )

    foreach ($cell in (Get-AbsoluteBlocks -Piece $Piece -OffsetX $OffsetX -OffsetY $OffsetY -RotationDelta $RotationDelta)) {
        if ($cell.X -lt 0 -or $cell.X -ge $Width) {
            return $true
        }
        if ($cell.Y -ge $Height) {
            return $true
        }
        if ($cell.Y -ge 0 -and $Board[$cell.Y][$cell.X] -ne 0) {
            return $true
        }
    }

    return $false
}

function Lock-Piece {
    param(
        [int[][]]$Board,
        $Piece
    )

    foreach ($cell in (Get-AbsoluteBlocks -Piece $Piece)) {
        if ($cell.Y -ge 0 -and $cell.Y -lt $Height -and $cell.X -ge 0 -and $cell.X -lt $Width) {
            $Board[$cell.Y][$cell.X] = $Piece.Id
        }
    }
}

function Clear-Lines {
    param([int[][]]$Board)

    $keptRows = New-Object 'System.Collections.Generic.List[int[]]'
    $cleared = 0

    for ($y = 0; $y -lt $Height; $y++) {
        $isFull = $true
        for ($x = 0; $x -lt $Width; $x++) {
            if ($Board[$y][$x] -eq 0) {
                $isFull = $false
                break
            }
        }

        if ($isFull) {
            $cleared++
        }
        else {
            $keptRows.Add($Board[$y])
        }
    }

    $newBoard = New-Object 'int[][]' $Height
    $insert = 0
    for ($i = 0; $i -lt $cleared; $i++) {
        $newBoard[$insert] = New-EmptyRow -W $Width
        $insert++
    }
    for ($i = 0; $i -lt $keptRows.Count; $i++) {
        $newBoard[$insert] = $keptRows[$i]
        $insert++
    }

    return [pscustomobject]@{
        Board = $newBoard
        Cleared = $cleared
    }
}

function Try-Move {
    param(
        [int[][]]$Board,
        $Piece,
        [int]$DX,
        [int]$DY
    )

    if (-not (Test-Collision -Board $Board -Piece $Piece -OffsetX $DX -OffsetY $DY)) {
        $Piece.X += $DX
        $Piece.Y += $DY
        return $true
    }

    return $false
}

function Try-Rotate {
    param(
        [int[][]]$Board,
        $Piece,
        [int]$Dir
    )

    $kicks = @(
        @(0,0), @(-1,0), @(1,0), @(-2,0), @(2,0), @(0,-1)
    )

    foreach ($k in $kicks) {
        if (-not (Test-Collision -Board $Board -Piece $Piece -OffsetX $k[0] -OffsetY $k[1] -RotationDelta $Dir)) {
            $Piece.X += $k[0]
            $Piece.Y += $k[1]
            $Piece.Rotation = (($Piece.Rotation + $Dir) % 4 + 4) % 4
            return $true
        }
    }

    return $false
}

function Get-CellToken {
    param([int]$Value)
    if ($Value -eq 0) {
        return ' .'
    }
    return '[]'
}

function Draw-Game {
    param(
        [int[][]]$Board,
        $Piece,
        [int]$Score,
        [int]$Lines,
        [bool]$Paused,
        [bool]$GameOver
    )

    $overlay = New-Object 'int[][]' $Height
    for ($y = 0; $y -lt $Height; $y++) {
        $overlay[$y] = New-Object 'int[]' $Width
        for ($x = 0; $x -lt $Width; $x++) {
            $overlay[$y][$x] = $Board[$y][$x]
        }
    }

    foreach ($cell in (Get-AbsoluteBlocks -Piece $Piece)) {
        if ($cell.Y -ge 0 -and $cell.Y -lt $Height -and $cell.X -ge 0 -and $cell.X -lt $Width) {
            $overlay[$cell.Y][$cell.X] = $Piece.Id
        }
    }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('PowerShell Tetris')
    [void]$sb.AppendLine('')

    $border = '+' + ('--' * $Width) + '+'
    [void]$sb.AppendLine($border)
    for ($y = 0; $y -lt $Height; $y++) {
        [void]$sb.Append('|')
        for ($x = 0; $x -lt $Width; $x++) {
            [void]$sb.Append((Get-CellToken -Value $overlay[$y][$x]))
        }
        [void]$sb.AppendLine('|')
    }
    [void]$sb.AppendLine($border)
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Score: $Score")
    [void]$sb.AppendLine("Lines: $Lines")
    [void]$sb.AppendLine('Controls: Left/Right move, Down soft drop, Up rotate, Space hard drop, P pause, R restart, Q quit')

    if ($GameOver) {
        [void]$sb.AppendLine('Status: Game Over (R to restart)')
    }
    elseif ($Paused) {
        [void]$sb.AppendLine('Status: Paused')
    }
    else {
        [void]$sb.AppendLine('Status: Running')
    }

    [Console]::SetCursorPosition(0, 0)
    Write-Host ($sb.ToString()) -NoNewline
}

function New-GameState {
    $board = New-Board -W $Width -H $Height
    $piece = New-Piece -SpawnX ([Math]::Floor($Width / 2))
    $over = Test-Collision -Board $board -Piece $piece

    return [pscustomobject]@{
        Board = $board
        Piece = $piece
        Score = 0
        Lines = 0
        Paused = $false
        GameOver = $over
        LastDrop = [DateTime]::UtcNow
    }
}

$hasInteractiveConsole = $true
try {
    $null = [Console]::WindowWidth
}
catch {
    $hasInteractiveConsole = $false
}

if (-not $hasInteractiveConsole) {
    Write-Host 'This game requires an interactive console. Run it in Windows PowerShell.'
    return
}

$originalCursorVisible = [Console]::CursorVisible
$originalTreatControlC = [Console]::TreatControlCAsInput

try {
    [Console]::CursorVisible = $false
    [Console]::TreatControlCAsInput = $true
    [Console]::Clear()

    $state = New-GameState
    $quit = $false

    while (-not $quit) {
        while ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)

            if ($key.Key -eq [ConsoleKey]::Q) {
                $quit = $true
                break
            }

            if ($key.Key -eq [ConsoleKey]::R) {
                $state = New-GameState
                continue
            }

            if ($key.Key -eq [ConsoleKey]::P) {
                if (-not $state.GameOver) {
                    $state.Paused = -not $state.Paused
                }
                continue
            }

            if ($state.GameOver -or $state.Paused) {
                continue
            }

            switch ($key.Key) {
                ([ConsoleKey]::LeftArrow) {
                    [void](Try-Move -Board $state.Board -Piece $state.Piece -DX -1 -DY 0)
                }
                ([ConsoleKey]::RightArrow) {
                    [void](Try-Move -Board $state.Board -Piece $state.Piece -DX 1 -DY 0)
                }
                ([ConsoleKey]::DownArrow) {
                    if (Try-Move -Board $state.Board -Piece $state.Piece -DX 0 -DY 1) {
                        $state.Score += 1
                    }
                }
                ([ConsoleKey]::UpArrow) {
                    [void](Try-Rotate -Board $state.Board -Piece $state.Piece -Dir 1)
                }
                ([ConsoleKey]::Spacebar) {
                    $dropDistance = 0
                    while (Try-Move -Board $state.Board -Piece $state.Piece -DX 0 -DY 1) {
                        $dropDistance++
                    }
                    if ($dropDistance -gt 0) {
                        $state.Score += ($dropDistance * 2)
                    }

                    Lock-Piece -Board $state.Board -Piece $state.Piece
                    $result = Clear-Lines -Board $state.Board
                    $state.Board = $result.Board
                    $state.Lines += $result.Cleared
                    $state.Score += $ScoreTable[$result.Cleared]

                    $state.Piece = New-Piece -SpawnX ([Math]::Floor($Width / 2))
                    if (Test-Collision -Board $state.Board -Piece $state.Piece) {
                        $state.GameOver = $true
                    }
                    $state.LastDrop = [DateTime]::UtcNow
                }
            }
        }

        if (-not $quit -and -not $state.GameOver -and -not $state.Paused) {
            $elapsed = ([DateTime]::UtcNow - $state.LastDrop).TotalMilliseconds
            if ($elapsed -ge $DropIntervalMs) {
                if (-not (Try-Move -Board $state.Board -Piece $state.Piece -DX 0 -DY 1)) {
                    Lock-Piece -Board $state.Board -Piece $state.Piece

                    $result = Clear-Lines -Board $state.Board
                    $state.Board = $result.Board
                    $state.Lines += $result.Cleared
                    $state.Score += $ScoreTable[$result.Cleared]

                    $state.Piece = New-Piece -SpawnX ([Math]::Floor($Width / 2))
                    if (Test-Collision -Board $state.Board -Piece $state.Piece) {
                        $state.GameOver = $true
                    }
                }
                $state.LastDrop = [DateTime]::UtcNow
            }
        }

        if (-not $quit) {
            Draw-Game -Board $state.Board -Piece $state.Piece -Score $state.Score -Lines $state.Lines -Paused $state.Paused -GameOver $state.GameOver
            Start-Sleep -Milliseconds $TickMs
        }
    }
}
finally {
    [Console]::CursorVisible = $originalCursorVisible
    [Console]::TreatControlCAsInput = $originalTreatControlC
    Write-Host ''
    Write-Host 'Exited Tetris.'
}
