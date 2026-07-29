async hard => {
	const wsProtocol = location.protocol === 'https:' ? 'wss:' : 'ws:'
	const addr = `${wsProtocol}//${location.host}/live-server-ws`
	const sleep = x => new Promise(r => setTimeout(r, x))
	const preload = async (url, requireSuccess) => {
		const resp = await fetch(url, { cache: 'reload' })
		if (requireSuccess && (!resp.ok || resp.status !== 200)) {
			throw new Error()
		}
	}
	const preloadNode = (n, ps) => {
		if (n.tagName === 'SCRIPT' && n.src) {
			ps.push(preload(n.src, false))
			return
		}
		if (n.tagName === 'LINK' && n.href) {
			ps.push(preload(n.href, false))
			return
		}
		let c = n.firstChild
		while (c) {
			const nc = c.nextSibling
			preloadNode(c, ps)
			c = nc
		}
	}
	let reloading = false
	let scheduled = false
	async function reload() {
		if (reloading) {
			scheduled = true
			return
		}
		let ifr
		reloading = true
		while (true) {
			scheduled = false
			const url = location.origin + location.pathname
			const promises = []
			preloadNode(document.head, promises)
			preloadNode(document.body, promises)
			await Promise.allSettled(promises)
			try {
				await new Promise(resolve => {
					ifr = document.createElement('iframe')
					ifr.src = url + '?reload'
					ifr.style.display = 'none'
					ifr.onload = resolve
					document.body.appendChild(ifr)
				})
			} catch {}
			const meta = ifr.contentDocument.head.querySelector(
				'meta[name="live-server"]'
			)
			if (
				meta &&
				meta.tagName === 'META' &&
				meta.name === 'live-server' &&
				meta.content === 'reload'
			) {
				if (!scheduled) {
					if (hard) {
						location.reload()
					} else {
						reloading = false
						document.head.replaceWith(ifr.contentDocument.head)
						document.body.replaceWith(ifr.contentDocument.body)
						ifr.remove()
						console.log('[Live Server] Reloaded')
					}
					return
				}
			}
			if (ifr) {
				ifr.remove()
			}
			await sleep(500)
		}
	}
	let connectedInterrupted = false
	while (true) {
		try {
			await new Promise(resolve => {
				const ws = new WebSocket(addr)
				ws.onopen = () => {
					console.log('[Live Server] Connection Established')
					if (connectedInterrupted) {
						reload()
					}
				}
				ws.onmessage = reload
				ws.onerror = () => ws.close()
				ws.onclose = resolve
			})
		} catch {}
		connectedInterrupted = true
		await sleep(3000)
		console.log('[Live Server] Reconnecting...')
	}
}
