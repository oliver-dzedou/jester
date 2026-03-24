set -euo pipefail

if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null ; then
    ODIN_CMD="odin.exe"
else
    ODIN_CMD="odin"
fi

$ODIN_CMD run src \
    -warnings-as-errors \
    -vet-using-param \
    -vet-using-stmt \
    -vet-tabs \
    -vet-shadowing \
    -vet-cast \
    -vet-semicolon \
    -strict-style \
    -debug

