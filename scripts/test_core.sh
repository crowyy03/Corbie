#!/bin/sh
set -e
cd "$(dirname "$0")/../Packages/CorbieCore"
CORBIE_EXTERNAL_TESTING=1 swift build
CORBIE_EXTERNAL_TESTING=1 swift test "$@"
