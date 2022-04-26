{ pkgs }:

with pkgs.lib;

{
	keymaps = {
		# "shields/corne" = pkgs.fetchgit {
		# 	url = "https://github.com/diamondburned/zmk-config-corne";
		# 	rev = "c22619ab76f26a3bf9b0fa14955e10db3c5ac62c";
		# 	sha256 = "014lb6bv40d627xh9j58vi0516wvwwfqd1mn148pz17jml8kq2mc";
		# } + "/config/corne.keymap";
		"shields/corne" = "${../zmk-config-corne/config}/corne.keymap";
	};
	build = {
		board = "nice_nano";
		shields = [
			"corne_left"
			"corne_right"
		];
	};
}
