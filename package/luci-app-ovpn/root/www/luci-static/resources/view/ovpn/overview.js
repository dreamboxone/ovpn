/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2026 dreamboxone <https://t.me/routekernel1>
 * Part of ovpn - https://github.com/dreamboxone/ovpn
 */

'use strict';
'require view';
'require rpc';
'require poll';
'require ui';

var callState  = rpc.declare({ object: 'luci.ovpn', method: 'state',  expect: { '': {} } });
var callAction = rpc.declare({ object: 'luci.ovpn', method: 'action', params: [ 'name' ], expect: { '': {} } });

function badge(st) {
	var text, colour;
	/* Choosing a server is a minute of timed requests. Without saying so, the
	   whole wait looks exactly like a button that did nothing. */
	if (st.connected)                    { text = _('Connected');   colour = '#10b981'; }
	else if (st.status == 'selecting')   { text = _('Finding the fastest server…'); colour = '#f59e0b'; }
	else if (st.status == 'starting')    { text = _('Starting…'); colour = '#f59e0b'; }
	else if (st.status == 'failed')      { text = _('No server could be reached'); colour = '#ef4444'; }
	else if (st.status == 'idle')        { text = _('Ready to connect'); colour = '#94a3b8'; }
	else if (st.running)                 { text = _('Connecting…'); colour = '#f59e0b'; }
	else                                 { text = _('Disconnected'); colour = '#94a3b8'; }

	return E('span', {
		'style': 'background:' + colour + ';color:#fff;padding:4px 14px;border-radius:12px;' +
		         'font-weight:bold;display:inline-block'
	}, text);
}

function line(label, id) {
	return E('div', { 'style': 'display:flex;gap:10px;padding:4px 0;align-items:baseline' }, [
		E('span', { 'style': 'flex:0 0 150px;opacity:.75' }, label),
		E('span', { 'style': 'flex:1 1 auto;font-weight:500', 'id': id }, '-')
	]);
}

function setNode(id, content) {
	var n = document.getElementById(id);
	if (!n) return;
	while (n.firstChild) n.removeChild(n.firstChild);
	n.appendChild(content instanceof Node ? content
		: document.createTextNode(content == null || content === '' ? '-' : String(content)));
}

function render(st) {
	st = st || {};
	setNode('ovpn-state', badge(st));
	setNode('ovpn-server', st.connected ? (st.server || '-') : '-');
	setNode('ovpn-latency', st.connected && st.latency_ms > 0 ? st.latency_ms + ' ms' : '-');

	var busy = (st.status == 'selecting' || st.status == 'starting');
	var connect = document.getElementById('ovpn-connect');
	var disconnect = document.getElementById('ovpn-disconnect');
	/* While a selection is running neither button may be pressed: the work
	   is already in flight and a second press would start a second one. */
	if (connect)    connect.disabled = busy || !!st.enabled;
	if (disconnect) disconnect.disabled = busy || !st.enabled;

	setNode('ovpn-why', busy
		? _('Every server is being tried with a real request, and the fastest one wins. This takes about half a minute.')
		: '');
}

function act(name) {
	return callAction(name).then(function() {
		return callState().then(render);
	});
}

return view.extend({
	load: function() {
		/* Start measuring as the page opens, so that by the time the reader
		   has decided to press Connect the answer is already there. Nothing
		   is hidden: the badge says what is happening while it happens. The
		   backend ignores this when a selection already exists. */
		return callAction('prepare')
			.catch(function() {})
			.then(function() { return callState(); })
			.catch(function() { return {}; });
	},

	render: function(st) {
		var body = E('div', {
			'style': 'background:rgba(127,127,127,.06);border:1px solid rgba(127,127,127,.20);' +
			         'border-radius:8px;padding:16px;max-width:520px'
		}, [
			E('div', { 'style': 'margin-bottom:14px' }, [
				E('span', { 'id': 'ovpn-state' }, '-')
			]),
			E('div', {
				'id': 'ovpn-why',
				'style': 'margin:-6px 0 12px 0;opacity:.7;font-size:13px'
			}, ''),
			line(_('Server'), 'ovpn-server'),
			line(_('Latency'), 'ovpn-latency'),
			E('div', { 'style': 'margin-top:16px;display:flex;gap:10px' }, [
				E('button', {
					'id': 'ovpn-connect',
					'class': 'btn cbi-button cbi-button-apply',
					'click': ui.createHandlerFn(this, function() { return act('connect'); })
				}, _('Connect')),
				E('button', {
					'id': 'ovpn-disconnect',
					'class': 'btn cbi-button cbi-button-reset',
					'click': ui.createHandlerFn(this, function() { return act('disconnect'); })
				}, _('Disconnect'))
			])
		]);

		poll.add(function() {
			return callState().then(render).catch(function() {});
		}, 3);

		var page = E([], [ E('h2', {}, 'ovpn'), body ]);
		render(st);
		return page;
	},

	handleSave: null,
	handleSaveApply: null,
	handleReset: null
});
