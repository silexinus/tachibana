# tachibana
Simple interface for converting a handful of SMILES using OpenBabel. This way you won't have to recall the loong OpenBabel command the next time you want to, say, canonicalize a SMILES.

I would ocassionally need a simple `obabel` conversion but couldn't remember all the necessary flags. This eventually warranted a standalone script, and it kept growing. Now you too can use `obabel` without having to remember all the flags for that one call you used weeks ago.

`tachibana` can also:
* Convert a smi to xyz coordinates.
* Write the molecule's chemical formula as plain text, or in `chemformula.sty` or `mhchem.sty` syntax.

## Installation
1. Download `tachibana.sh` to a folder such as `~/Bash-scripts/` or `~/Chem-scripts/`
2. Add a line like this (with the folder name you picked) to your `~/.bashrc` or `~/.bash_aliases` (if the latter, ensure that the aliases file is called from the `~/.bashrc` file)
```
alias tachibana="~/Bash-scripts/tachibana.sh"
```
3. Run `$:source ~/.bashrc`
4. Run `$:tachibana -i` to finish the installation. This creates a config file and finishes the setup.
5. Run `$:tachibana "OCC"` to canonicalize ethanol. You'll get the output `CCO`.
6. Run `$:tachibana -f "OC(=O)CC1(CCCCC1)CN"` to calculate the formula of gabapentin. You'll get the output `C9H17NO2`.

## Usage
The default mode is canonicalization:
```
$:tachibana "OCC"
```
The output is `CCO`.

Get the xyz coordinates using `-x` or `--smi2xyz`
```
$:tachibana -x "C=O"
```
You can save the coordinates to disk by running, say, `$:tachibana -x "C=O" > formaldehyde.xyz`

Molecular formula as plain text:
```
$:tachibana -f "OC(=O)CC1(CCCCC1)CN"
```
The output is `C9H17NO2`.

Molecular formula in `chemformula.sty` syntax (the -n comes from Niederberger, the package's author):
```
$:tachibana -n "OC(=O)CC1(CCCCC1)CN"
```

Molecular formula in `mhchem.sty` syntax:
```
$:tachibana -m "OC(=O)CC1(CCCCC1)CN"
```

Other flags:
* `-h`: print help message
* `-u`: update the program
* `-v`: display local version
* `-U`: display local and newest versions

## System requirements
* OpenBabel (obabel command must be in PATH)

## License
GPLv3
