# zmk-nix

```nix
nix-shell
build-zmk
```

## Configuration

See [config.nix](config.nix).

```nix
{
	keymaps = {
		"shields/corne" = pkgs.fetchgit {
			url = "https://github.com/diamondburned/zmk-config-corne";
			rev = "d3db3cac52b7e1a6f9352ab47e6df73f1158a319";
			sha256 = "1yi88kbsdl7jpj1yv0rrzkp10cfzv3nnf0v9fjfrhmhrv7vyk8vd";
		} + "/config/corne.keymap";
	};
	build = {
		board = "nice_nano";
		shields = [
			"corne_left"
			"corne_right"
		];
	};
}
```
