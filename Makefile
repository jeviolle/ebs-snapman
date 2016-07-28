#
# Copyright (C) 2015, Rick Briganti
#
# This file is part of ebs-snapman
# 
# ebs-snapman is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

PREFIX=/opt

help:
	@echo
	@echo 'help:'
	@echo
	@echo "  *default PREFIX is $(PREFIX)"
	@echo 
	@echo '  make testdeps           checks that all deps are met   '
	@echo '  make install            installs ebs-snapman to PREFIX '
	@echo '  make uninstall          removes ebs-snapman from PREFIX'
	@echo

testdeps:
	@echo "Testing dependencies..."
	@echo 
	@for i in "jq" "aws" "bash" "egrep" "grep" "sed" "awk" "expr" "perl" "sort"; do \
		echo -n "$$i	..." ;\
		which $$i > /dev/null 2>&1 ;\
		if [ $$? = 0 ];then \
			echo "found" ; \
		else \
			echo "not found"; \
			exit 1; \
		fi \
	done
	@echo 
	@echo "complete."


install:
	@echo "Installing ebs-snapman to $(PREFIX)/ebs-snapman"
	@echo 
	mkdir -v $(PREFIX)/ebs-snapman
	cp -vR src/* $(PREFIX)/ebs-snapman/
	chmod 755 $(PREFIX)/ebs-snapman/ebs-snapman.sh
	@echo
	@echo "complete."

uninstall:
	@echo "Removing ebs-snapman from $(PREFIX)/ebs-snapman"
	@echo
	rm -rv $(PREFIX)/ebs-snapman
	@echo
	@echo "complete."

.PHONY: help install uninstall
