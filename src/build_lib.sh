set -e

fan=fan
$fan inet/build.fan
$fan web/build.fan
$fan wisp/build.fan
$fan email/build.fan
$fan webmod/build.fan

$fan syntax/build.fan
$fan fandoc/build.fan
$fan compilerDoc/build.fan

$fan graphics/build.fan
$fan dom/build.fan
$fan domkit/build.fan
$fan testDomkit/build.fan

$fan compilerDoc -all
