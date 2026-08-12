#!/bin/bash

# TODO: Add an interface for accessing the other speed options (med, slow), then mention this in the readme. And let the user pick between openbabel (default) and rdkit (alternate backend)
# TODO: Add an argument like --update that compares tachibana's version with that on github and downloads it to the current folder if github has a newer version. Do this for all the toolbelt-level scripts, so it looks like this merits having a sh script that has the `compare local version with github' and another that downloads the file

# Tiny program for converting a SMILES to canonical SMILES, XYZ coordinates, or chemical formulas
# Use this program for manually converting a handful of molecules.
# For anything bigger than that, you're better off using milasestro

fileversions=".versions_bucellarii"
programname="tachibana"
urlupdater="https://raw.githubusercontent.com/silexinus/bucellarii-updater/main/bucellarii-updater.sh"
nameupdater="bucellarii-updater.sh"

# Function to print the readme
print_readme() {
    cat << 'EOF'
Handy OpenBabel interface for doing a few simple operations on a
  handful of SMILES. If you want to convert an entire dataset, use
  milasestro instead.

USAGE:
  $:tachibana [OPTIONS] <SMILES_STRING>

OPTIONS:
  Conversion modes (pick exactly one):
    --canon, -c              (default) Canonicalize a SMILES
    --smi2xyz, -x            Convert SMILES to XYZ coordinates using MMFF94
    --formula, -f            Print molecular formula as plain text
    --chemformula, --cf, -n  Print formula in chemformula TeX syntax (-n comes from Niederberger, chemformula's author)
    --mhchem, --mc, -m       Print formula in mhchem TeX syntax

  Other flags:
    -h, --help               Display this help message
    -u, --update             Updates the program
    -v, --version            Display the local version
    -U, --check-update       Display the local and newest versions

EXAMPLES:
  Canonicalize ethanol:
    $:tachibana "OCC"

  Convert aniline or formaldehyde to XYZ:
    $:tachibana "c1ccncc1" --smi2xyz
    $:tachibana -x "C=O"
  If you want to save the coordinates to disk, run something like this:
    $:tachibana -x "C=O" > formaldehyde.xyz

  Get molecular formula of gabapentin:
    $:tachibana "OC(=O)CC1(CCCCC1)CN" --formula
    $:tachibana -f "OC(=O)CC1(CCCCC1)CN"

  Get its formula in chemformula syntax:
    $:tachibana "OC(=O)CC1(CCCCC1)CN" --chemformula
    $:tachibana -n "OC(=O)CC1(CCCCC1)CN"

  Get its formula in mhchem syntax:
    $:tachibana "OC(=O)CC1(CCCCC1)CN" --mhchem

SYSTEM REQUIREMENTS:
  - OpenBabel (obabel command must be in PATH)
    Verify your OpenBabel install by running:
    $:obabel -V
    The output should look like this:
    Open Babel 3.1.1 -- Mar 31 2024 -- 06:39:03
EOF
}

# bucellarii interface (pt1 of 4)
call_bucellarii_updater() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    "$script_dir/bucellarii_updater.sh" "$@"
}

# bucellarii interface (pt2 of 4)
# I copied this fun from bucellarii-updater.sh , so once I do the fix mentioned herein, on that function, I have to update every copy manually
# Download with 20-second timeout
download_with_timeout() {
    local url="$1"
    local output="$2"
    local timeout="${3:-20}" # Default value is 20 seconds, but you can pass another value
    # here1 let the bucellarii-class programs have a flag that overrides this 20-second default value. Then, bucellarii-updater would have to weave this value into the workflow

    timeout "$timeout" curl -fsSL "$url" -o "$output" 2>/dev/null || \
    timeout "$timeout" wget -q "$url" -O "$output" 2>/dev/null || \
    return 1
}

# bucellarii interface (pt3 of 4)
ensure_updater() {
    local programname="$1"
    local nameupdater="$2"
    local action="$3"
    
    if [ -f "$nameupdater" ]; then
        call_bucellarii_updater --self-update
    else
        download_with_timeout "$urlupdater" "$nameupdater"
        chmod u+x "$nameupdater"
        if [ $? -eq 1 ]; then
            echo "Could not $action $programname. Network unavailable."
            exit 1
        fi
    fi
}

# bucellarii interface (pt4 of 4)
for arg in "$@"; do
    case "$arg" in
        # -i is really just a synonym of -u
        # It's easier to add it as a separate flag rather than
        #   dump the entire explanation of bucellarii_updater
        #   on a new user and how the scripts don't know their
        #   own versions and hence the updater handles that and 
        #   creates the versions file and all that.
        -i|-u|--update)
            ensure_updater "$programname" "$nameupdater" "update"
            call_bucellarii_updater --update "$programname"
            exit 0
            ;;
        -v|--version)
            grep "^${programname} " "$fileversions" || {
                echo -e "Error: Program '$programname' not found in $fileversions. Run\n  \$:$programname -u\nto update the program and save its version data to disk." >&2
                exit 1
            }
            exit 0
            ;;
        -U|--check-update)
            ensure_updater "$programname" "$nameupdater" "check-update"
            call_bucellarii_updater --check-update "$programname"
            exit 0
            ;;
    esac
done

# Run OpenBabel, suppress errors, keep the output on a single line
# Then pipe it through awk: select line 2 (NR==2) and print field 2 ($2).
# This gives us the molecule's formula. Here's an example babel call, where
#   the molecular formula is visible on line 2, word 2:
# $:obabel -ismi -:"C=O" -omolreport
# TITLE:
# FORMULA: CH2O
# MASS: 30.0260
# ATOM:         1   C TYPE: C2     HYB:  2 CHARGE:   0.2794
# ATOM:         2   O TYPE: O2     HYB:  2 CHARGE:  -0.2794
# BOND:         0 START:         1 END:         2 ORDER:   2
getmolfor() {
    local smiles="$1"

    obabel -:"$smiles" -omolreport 2>/dev/null \
        | awk 'NR==2 {print $2}'
        #| tr -d '\n' \ # <- an earlier version had a tr -d step to drop any weird characters but it also stopped this block from working so I cut it
}

# Initialize variables
string=""
mode=""
mode_count=0

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            print_readme
            exit 0
            ;;
        --canon|-c)
            mode="canon"
            ((mode_count++))
            ;;
        --smi2xyz|-x)
            mode="xyz"
            ((mode_count++))
            ;;
        --formula|-f)
            mode="formula"
            ((mode_count++))
            ;;
        --chemformula|--cf|-n)
            mode="chemformula"
            ((mode_count++))
            ;;
        --mhchem|--mc|-m)
            mode="mhchem"
            ((mode_count++))
            ;;
        -*)
            echo "Error: Unknown flag '$arg'" >&2
            print_readme
            exit 1
            ;;
        *)
            string="$arg"
            ;;
    esac
done

# Check that exactly one mode was selected
if [[ $mode_count -gt 1 ]]; then
    echo "Error: Only one mode can be selected at a time" >&2
    print_readme
    exit 1
fi

# Check that we have a SMILES string
if [[ -z "$string" ]]; then
    print_readme
    exit 0
fi

# Default to canonicalization if no mode specified
if [[ -z "$mode" ]]; then
    mode="canon"
fi

# Function to parse formula and convert to Hill notation
to_hill_notation() {
    local formula="$1"
    local mode="$2" # "formula" or "chemformula" or "mhchem"

    # Extract charge if present (e.g., Fe++ or N++++ or O--)
    local charge=""
    if [[ "$formula" =~ ([-+]+)$ ]]; then
        local signs="${BASH_REMATCH[1]}"
        local count=${#signs}
        local sign="${signs:0:1}"
        charge="${sign}${count}"
        formula="${formula%${signs}}"
    fi

    # Parse formula into associative array
    declare -A atom_count
    local i=0

    while [[ $i -lt ${#formula} ]]; do
        char="${formula:$i:1}"

        # Single uppercase letter
        if [[ "$char" =~ ^[A-Z]$ ]]; then
            local elem="$char"
            i=$((i+1))

            # Check for lowercase letter (two-letter element)
            if [[ $i -lt ${#formula} && "${formula:$i:1}" =~ ^[a-z]$ ]]; then
                elem="${elem}${formula:$i:1}"
                i=$((i+1))
            fi

            # Check for count
            local count=1
            if [[ $i -lt ${#formula} && "${formula:$i:1}" =~ ^[0-9]$ ]]; then
                count=""
                while [[ $i -lt ${#formula} && "${formula:$i:1}" =~ ^[0-9]$ ]]; do
                    count="${count}${formula:$i:1}"
                    i=$((i+1))
                done
            fi

            atom_count[$elem]=$((${atom_count[$elem]:-0} + count))
        else
            i=$((i+1))
        fi
    done

    # Build Hill notation formula
    local result=""

    # Carbon first
    if [[ -n "${atom_count[C]}" ]]; then
        if [[ "$mode" == "formula" ]]; then
            result=$(format_atom_justprint "C" "${atom_count[C]}")
        else
            result=$(format_atom "C" "${atom_count[C]}")
        fi
    fi

    # Hydrogen second
    if [[ -n "${atom_count[H]}" ]]; then
        if [[ "$mode" == "formula" ]]; then
            result="${result}$(format_atom_justprint "H" "${atom_count[H]}")"
        else
            result="${result}$(format_atom "H" "${atom_count[H]}")"
        fi
    fi

    # Other elements alphabetically
    for elem in $(printf '%s\n' "${!atom_count[@]}" | grep -v '^[CH]$' | sort); do
        if [[ "$mode" == "formula" ]]; then
            result="${result}$(format_atom_justprint "$elem" "${atom_count[$elem]}")"
        else
            result="${result}$(format_atom "$elem" "${atom_count[$elem]}")"
        fi
    done

    # Add charge if present (simplify ±1 to ± only)
    if [[ -n "$charge" ]]; then
        if [[ "$charge" == "+1" ]]; then
            result="${result}^+"
        elif [[ "$charge" == "-1" ]]; then
            result="${result}^-"
        else
            result="${result}^${charge}"
        fi
    fi

    echo "$result"
}

# Format atom with count (handles brackets for counts > 9)
format_atom() {
    local elem="$1"
    local count="$2"

    if [[ $count -eq 1 ]]; then
        echo "$elem"
    else
        echo "${elem}${count}"
    fi
}

# Format atom with count (no brackets nor subindices; this one
#   is called if you only want to print the formula to the screen,
#   so you'd rather have C11H14O instead of C_{11}H_{14}O
format_atom_justprint() {
    local elem="$1"
    local count="$2"

    if [[ $count -eq 1 ]]; then
        echo "$elem"
    else
        echo "${elem}${count}"
    fi
}

# Format for chemformula TeX package
format_chemformula() {
    local formula="$1"

    # Ensure charges have brackets if they're multi-character
    formula=$(echo "$formula" | sed 's/\^\([+-][0-9]\+\)$/^{\1}/g; s/\^\([+-]\)$/^{\1}/g')

    echo "\\ch{$formula}"
}

# Format for mhchem TeX package
format_mhchem() {
    local formula="$1"

    # Ensure charges have brackets if they're multi-character
    formula=$(echo "$formula" | sed 's/\^\([+-][0-9]\+\)$/^{\1}/g; s/\^\([+-]\)$/^{\1}/g')

    echo "\\ce{$formula}"
}

# Execute the selected mode
case "$mode" in
    canon)
        # Mode: Canonicalize using openbabel
        output=$(obabel -ismi -:"$string" -ocan 2>&1)
        exit_code=$?

        if [[ $exit_code -ne 0 ]]; then
            echo "$output" >&2
            exit $exit_code
        else
            # Print only the canonical SMILES (last line typically)
            echo "$output" | tail -n 1
        fi
        ;;
    xyz)
        # Mode: Convert SMILES to XYZ format
        output=$(obabel -ismi -:"$string" -oxyz --gen3d --ff=MMFF94 slowest -c 2>/dev/null)
        exit_code=$?

        if [[ $exit_code -ne 0 ]]; then
            # On error, run again to capture stderr for error messages
            obabel -ismi -:"$string" -oxyz --gen3d --ff=MMFF94 slowest -c 2>/dev/null
            exit $exit_code
        else
            echo "$output"
        fi
        ;;
    formula)
        # Mode: Get molecular formula (readable)
        formula=$(getmolfor "$string")

        if [[ -z "$formula" ]]; then
            echo "Error: Could not parse SMILES with obabel" >&2
            exit 1
        fi

        hill_formula=$(to_hill_notation "$formula" "$mode")
        echo "$hill_formula"
        ;;
    chemformula)
        # Mode: Get formula in chemformula syntax
        formula=$(getmolfor "$string")

        if [[ -z "$formula" ]]; then
            echo "Error: Could not parse SMILES with obabel" >&2
            exit 1
        fi

        hill_formula=$(to_hill_notation "$formula" "$mode")
        format_chemformula "$hill_formula"
        ;;
    mhchem)
        # Mode: Get formula in mhchem syntax
        formula=$(getmolfor "$string")

        if [[ -z "$formula" ]]; then
            echo "Error: Could not parse SMILES with obabel" >&2
            exit 1
        fi

        hill_formula=$(to_hill_notation "$formula" "$mode")
        format_mhchem "$hill_formula"
        ;;
esac
