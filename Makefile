.PHONY: install dry-run doctor doctor-fix update

install:
	bash scripts/install.sh

dry-run:
	bash scripts/install.sh --dry-run

doctor:
	bash scripts/doctor.sh

doctor-fix:
	bash scripts/doctor.sh --fix

update:
	git pull --ff-only
	bash scripts/install.sh --non-interactive
