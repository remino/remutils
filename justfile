clean:
	rm -f *.tar.gz *.tar.gz.sha256

list:
	find . -depth 1 -type d -print0 | while read -r -d '' dir; do name="$(basename "$dir")"; [ -f "$dir/$name" ] && echo "$name" || true; done
