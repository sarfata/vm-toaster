
MAKE ?= make
QMAKE := ${MAKE} --no-print-directory

PLATFORM := x86
MEDIC_CORE_VERSION := 1.2.2
MEDIC_CORE_ROOT := /srv/software/medic-core/v${MEDIC_CORE_VERSION}/${PLATFORM}

all: packages build-iso

iso: build-iso

compile:
	@(cd source && ${QMAKE})

copy:
	@(cd source && ${QMAKE} copy)

packages: strip-binaries medic-core-pkg concierge-pkg java-pkg system-services-pkg vm-tools-pkg gardener-pkg

clean:
	rm -f output/* && \
	rm -rf staging/packages

distclean: clean
	rm -rf "initrd/${PLATFORM}/lib/modules/"* && \
	rm -f images/${PLATFORM}/iso/boot/kernel \
	  "images/${PLATFORM}/iso/boot/image.xz" "images/${PLATFORM}/iso/packages"/* && \
	(cd source && ${MAKE} clean)

clean-iso:
	rm -f "images/${PLATFORM}/iso/packages"/*.vpkg \
	  "images/${PLATFORM}/iso/boot/image.gz" "images/${PLATFORM}/iso/boot/kernel"

build-iso: build-initrd verify-packages
	@echo -n 'Creating ISO image... ' && \
	cd "images/${PLATFORM}/iso" && mkisofs -J -R -V 'Medic Mobile VM' \
		-o ../../../output/image-${PLATFORM}.iso \
		-boot-load-size 4 -boot-info-table \
		-no-emul-boot -b boot/isolinux/isolinux.bin \
		-c boot/isolinux/boot.cat . &>/dev/null && \
	echo 'done.'

build-initrd:
	@echo -n 'Creating initrd image... ' && \
	cp -a initrd/common/* "initrd/${PLATFORM}/" && \
	cd "initrd/${PLATFORM}" && \
		find * | cpio -o -H newc 2>/dev/null \
		  | sh ../../source/core/linux/scripts/xz_wrap.sh \
			> ../../images/${PLATFORM}/iso/boot/image.xz && \
	echo 'done.'

strip-binaries:
	@echo -n "Removing unnecessary symbols... " && \
	./scripts/strip-binaries packages && \
	echo 'done.'

verify-packages:
	@echo -n "Verifying package contents... " && \
	./scripts/verify-packages "${MEDIC_CORE_ROOT}" && \
	echo 'done.'

concierge-pkg:
	@echo -n "Compressing package 'concierge'... " && \
	scripts/build-package 'concierge' 1000 && \
	echo 'done.'

java-pkg: copy-java-template
	@echo -n "Compressing package 'java'... " && \
	scripts/build-package 'java' 1790 && \
	echo 'done.'

copy-java-template:
	@echo -n "Copying package template for 'java'... " && \
	rm -rf packages/java/software && \
	cp -a "templates/java/${PLATFORM}/software" packages/java/software && \
	echo 'done.'

medic-core-pkg:
	@echo -n "Compressing package 'medic-core'... " && \
	scripts/build-package 'medic-core' 1220 && \
	echo 'done.'

system-services-pkg:
	@echo -n "Compressing package 'system-services'... " && \
	scripts/build-package 'system-services' 1000 && \
	echo 'done.'

vm-tools-pkg:
	@echo -n "Compressing package 'vm-tools'... " && \
	scripts/build-package 'vm-tools' 9220 && \
	echo 'done.'

shrink-gardener:
	@./scripts/shrink-gardener

gardener-pkg: shrink-gardener
	@echo -n "Compressing package 'gardener'... " && \
	scripts/build-package 'gardener' 1010 && \
	echo 'done.'

convert-boot-logo:
	for file in logo-medic logo-medic-gray; do \
		pngtopnm "kernel/boot-logo/$$file.png" | ppmquant 224 2>/dev/null \
			| pnmtoplainpnm > "kernel/boot-logo/$$file.ppm"; \
	done

