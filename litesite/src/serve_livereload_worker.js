'use strict'
var ports = []
var es = null
var lastHello = null

function broadcast(msg) {
	ports = ports.filter(function (port) {
		try {
			port.postMessage(msg)
			return true
		} catch (_) {
			return false
		}
	})
}

function connect() {
	es = new EventSource('/__litesite/livereload')
	es.addEventListener('hello', function (event) {
		lastHello = event.data
		broadcast({ kind: 'hello', data: event.data })
	})
	es.addEventListener('change', function (event) {
		broadcast({ kind: 'change', data: event.data })
	})
	es.onerror = function () {
		broadcast({ kind: 'error' })
	}
}

self.onconnect = function (event) {
	var port = event.ports[0]
	ports.push(port)
	port.start()
	port.onmessage = function (message) {
		if (message.data === 'bye') {
			ports = ports.filter(function (candidate) {
				return candidate !== port
			})
		}
	}
	if (lastHello !== null) {
		try {
			port.postMessage({ kind: 'hello', data: lastHello })
		} catch (_) {}
	}
	if (es === null) {
		connect()
	}
}
