---
title: Keynsham Soc Configuration
layout: default
---

<h1>Keynsham SoC Configuration</h1>

<h2>CPU</h2>
{% assign cpu = site.data.keynsham.cpu %}
<p><strong>Manufacturer:</strong> {{ cpu.manufacturer }}</p>
<p><strong>Model:</strong> {{ cpu.model }}</p>
<p><strong>Clock Speed:</strong> {{ cpu.clock_speed }}</p>

<h2>Instruction Cache</h2>
<p><strong>Size:</strong> {{ cpu.icache.size }}</p>
<p><strong>Line size:</strong> {{ cpu.icache.line_size }}</p>

<h2>Memory Map</h2>
<table>
<tr><th>Address</th><th>Size</th><th>Name</th></tr>
{% for p in site.data.keynsham.peripherals | sort: "address" %}
  <tr><td>{{ p.address | HexFilter::as_hex }}</td><td>{{ p.size }}</td><td>{{ p.name }}</td></tr>
{% endfor %}
</table>
