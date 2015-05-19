eight-ball.min.js: eight-ball.ls
	browserify --verbose --debug -t liveify -g uglifyify -o $@ $<

watch: eight-ball.ls
	watchify --verbose --debug -t liveify -g uglifyify -o eight-ball.min.js $<

clean:
	rm eight-ball.min.js

.PHONY: watch clean
