#!/usr/bin/env bash

set -e
declare -A IMAGES

CONFIG='
{
	"stable": {
		"debian": "bullseye",
		"version": "6.0.8",
		"tags": "6.0",
		"pkg-commit": "10da6a585eb7d8defe9d273a51df5b133500eb6b",
		"dist-sha512": "73ed2f465ba3b11680b20a70633fc78da9b3eac68395f927b7ff02f4106b6cc92a2b395db2813a0605da2771530e5c4fc594eaf5a9a32bf2e42181b6dd90cf3f"
	},
       "old": {
               "debian": "bullseye",
               "version": "6.6.1",
               "tags": "6.6",
               "pkg-commit": "d3e6a3fad7d4c2ac781ada92dcc246e7eef9d129",
               "dist-sha512": "af3ee1743af2ede2d3efbb73e5aa9b42c7bbd5f86163ec338c8afd1989c3e51ff3e1b40bed6b72224b5d339a74f22d6e5f3c3faf2fedee8ab4715307ed5d871b"
       },
	"fresh": {
		"debian": "bullseye",
		"version": "7.0.1",
		"tags": "7.0 latest",
		"pkg-commit": "d3e6a3fad7d4c2ac781ada92dcc246e7eef9d129",
		"dist-sha512": "7541d50b03a113f0a13660d459cc4c2eb45d57fb19380ab56a5413a4e5d702f9c0856585f09aeea6084a239ad8c69017af3805a864540b4697e0eac29f00b408"
	},
	"next": {
		"debian": "bullseye",
		"version": "7.0.1",
		"tags": "7.0 latest",
		"pkg-commit": "d3e6a3fad7d4c2ac781ada92dcc246e7eef9d129",
		"dist-sha512": "7541d50b03a113f0a13660d459cc4c2eb45d57fb19380ab56a5413a4e5d702f9c0856585f09aeea6084a239ad8c69017af3805a864540b4697e0eac29f00b408"
	}
}'

update_dockerfiles() {
	DEBIAN=`echo $CONFIG | jq -r ".[\"$1\"][\"debian\"]"`
	VARNISH_VERSION=`echo $CONFIG | jq -r ".[\"$1\"][\"version\"]"`
	DIST_SHA512=`echo $CONFIG | jq -r ".[\"$1\"][\"dist-sha512\"]"`
	PKG_COMMIT=`echo $CONFIG | jq -r ".[\"$1\"][\"pkg-commit\"]"`

	sed $1/$2/Dockerfile.tmpl \
		-e "s/@DEBIAN@/$DEBIAN/" \
		-e "s/@VARNISH_VERSION@/$VARNISH_VERSION/" \
		-e "s/@DIST_SHA512@/$DIST_SHA512/" \
		-e "s/@PKG_COMMIT@/$PKG_COMMIT/" \
		> $1/$2/Dockerfile
}

populate_dockerfiles() {
	for i in `echo $CONFIG | jq -r 'keys | .[]'`; do
		update_dockerfiles $i debian
		[ "$i" != "stable" ] && update_dockerfiles $i alpine
	done
}

update_library(){
	version=`echo $CONFIG | jq -r ".[\"$1\"][\"version\"]"`
	tags=`echo $CONFIG | jq -r ".[\"$1\"][\"tags\"]"`
	tags="$1 $version $tags"

	if [ "$2" != "debian" ]; then
		tags=`echo "$tags" | sed -e "s/\( \|$\)/-$2\1/g" -e "s/latest-$2/$2/"`
	fi

	cat >> library.varnish <<- EOF

		Tags: `echo $tags | sed 's/ \+/, /g'`
		Architectures: amd64, arm32v7, arm64v8, i386, ppc64le, s390x
		Directory: $1/$2
		GitCommit: `git log -n1 --pretty=oneline $1/$2 | cut -f1 -d" "`
	EOF
}

populate_library() {
	cat > library.varnish <<- EOF
		# this file was generated using https://github.com/varnish/docker-varnish/blob/`git rev-parse HEAD`/populate.sh
		Maintainers: Guillaume Quintard <guillaume@varni.sh> (@gquintard)
		GitRepo: https://github.com/varnish/docker-varnish.git
	EOF

	for i in `echo $CONFIG | jq -r 'keys | .[]'`; do
		if [ "$i" = "next" ]; then
			continue
		fi
		update_library $i debian
		if [ "$i" != "stable" ]; then
			update_library $i alpine
		fi
	done
}

case "$1" in
	dockerfiles)
		populate_dockerfiles
		;;
	library)
		populate_library
		;;
	*)
		echo invalid choice
		exit 1
		;;
esac
