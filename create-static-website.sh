#!/bin/bash
rm -rf _book && gitbook build && cp -r _book/* .

