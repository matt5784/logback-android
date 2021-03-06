#!/bin/sh
##############################################################################
# Logback: the reliable, generic, fast and flexible logging framework.
# Copyright (C) 2011-2012, Anthony Trinh. All rights reserved.
# Copyright (C) 1999-2011, QOS.ch. All rights reserved.
#
# This program and the accompanying materials are dual-licensed under
# either the terms of the Eclipse Public License v1.0 as published by
# the Eclipse Foundation
#
#   or (per the licensee's choosing)
#
# under the terms of the GNU Lesser General Public License version 2.1
# as published by the Free Software Foundation.
##############################################################################

if [ ! $1 ]; then
	echo "Usage: $0 {version}"
	exit 1
fi

readme=../../README.md
cd build/ant || exit 1

#
# Release version "x.x.x-N"
#
# where 
#	x.x.x is the version of logback on which logback-android is based
# and 
#	N is the integral release number of logback-android.
#
version=$1
outf=logback-android-${version}.jar

echo "Starting release process for logback-android ${version}..."

# prompt for keystore password (hide input)
echo "Enter keystore password to sign JAR: "
stty -echo
read password
stty echo

#
# Build the JAR and print its MD5. The last line uses GNU sed (gsed)
# to update the README with the current release version.
#
ant clean release -Dkey.store.password=${password} -Dversion=${version} && \
md5 bin/${outf} && \
echo "Updating README.md..." && \
gsed -i -e "s/logback-android-[^j]*\.jar/${outf}/" \
-e "s/doc\/[0-9]\+\.[0-9]\+\.[0-9]\+\-[0-9]\+/doc\/${version}/" \
-e "s/\*\*[0-9\.\-]*\*\*/\*\*${version}\*\*/" \
-e "s/\(logback-android.*MD5\:\).*/\1 \`$(md5 bin/${outf} | awk '{print $4}')\`)/" ${readme}

git add ${readme}
git commit -m "release ${version}"

echo "Updating snapshot version..."
gsed -i -e "s/\(version\.default\s*=\s*\)\(.*\)/\1${version}-SNAPSHOT/g" ant.properties
git add ant.properties

echo "Deleting existing tag if it exists..."
git tag -l | grep -q v_${version} && git tag -d v_${version}
echo "Tagging as ${version}..."
git tag -a v_${version} -m "tagging as ${version}"

echo "Generating javadoc..."
ant doc -Dversion=${version}

# Update the web pages
git clone -b gh-pages https://github.com/tony19/logback-android.git gh-pages
cd gh-pages
mv ../doc/${version} doc/.
git add doc/${version}

echo "Updating index.html..."
gsed -i -e "s/logback-android-[^j]*\.jar/${outf}/g" \
-e "s/doc\/[0-9]\+\.[0-9]\+\.[0-9]\+\-[0-9]\+/doc\/${version}/g" index.html
git add index.html

insdiv="<div id=\"${version}\" class=\"release\">\n\
\t\t<div class=\"version\">${version}</div>\n\
\t\t<div class=\"reldate\">Released on $(date +'%m-%d-%Y')</div>\n\
\t\t<ul>\n\
\t\t\t<li>Sync with Logback <a href=\"http://logback.qos.ch/news.html\">${version%-*}</a></li>\n\
\t\t</ul>\n\
\t</div>"

# insert the release div if not already present (it shouldn't be present)
grep -q "id=\"${version}\" class=\"release\"" changelog.html
if [ $? -gt 0 ]; then
	echo "Updating changelog.html..."
	gsed -i -e "s@<div id=[\"\']notes[\"\']>@&\n\t${insdiv}@" changelog.html
fi
git add changelog.html

# checkin changes to the web pages
git commit -m "release ${version}"

echo Done
