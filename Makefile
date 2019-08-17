VERSION=0.0.1
php5.6.9:
	docker run --rm -w /binary-builder -v `pwd`:/binary-builder -it cloudfoundry/cflinuxfs2 ./bin/binary-builder --name=php --version=5.6.9 --sha256=49527ba66357fe65bcd463dfb8dcff1b8879419f88b3c334f50696a2aceacb87

rebase:
	git remote add cf https://github.com/cloudfoundry/binary-builder.git | true
	git fetch cf
	git merge cf/master

release:
	ghr v$(VERSION) *tgz
