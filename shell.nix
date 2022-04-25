{ pkgs ? import <nixpkgs> {} }:

# https://sourcegraph.com/github.com/qmk/qmk_firmware/-/blob/shell.nix

let avrlibc = pkgs.pkgsCross.avr.libcCross;
	avrincl = pkgs.lib.concatMapStrings (x: x + " ") [
		"-isystem ${avrlibc}/avr/include"
		"-B${avrlibc}/avr/lib/avr5"
		"-L${avrlibc}/avr/lib/avr5"
		"-B${avrlibc}/avr/lib/avr35"
		"-L${avrlibc}/avr/lib/avr35"
		"-B${avrlibc}/avr/lib/avr51"
		"-L${avrlibc}/avr/lib/avr51"
	];

	initFile = pkgs.writeText "init.sh" ''
		export AVR_CFLAGS="${avrincl}"
		export AVR_ASFLAGS="${avrincl}"

		virtualenv venv
		. venv/bin/activate
		. ~/.bashrc
	'';

	fhs = pkgs.buildFHSUserEnv {
		name = "zmk-fhs-env";

		targetPkgs = pkgs: with pkgs; [
			python38
			python38Packages.pip
			python38Packages.virtualenv
			python38Packages.west

			clang-tools
			coreutils
			cmake
			dfu-programmer
			dfu-util
			pkgsCross.avr.buildPackages.binutils
			pkgsCross.avr.buildPackages.gcc8
			avrlibc
			avrdude
			git
		];

		runScript = ''bash --init-file ${initFile}'';
	};

in fhs.env
