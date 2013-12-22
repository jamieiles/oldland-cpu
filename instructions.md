---
title: Oldland Instruction Set
layout: default
---

<h1>Oldland Instruction Set</h1>

<a id="top" />
<ul>
{% for instr in site.data.instructions.instructions %}
<li><a href="#{{ instr[0] }}">{{ instr[0] }}</a></li>
{% endfor %}
</ul>

{% for instr in site.data.instructions.instructions %}
<a id="{{ instr[0] }}"><h2>{{ instr[0] }}</h2></a>
<p><strong>Class: {{ instr[1].class }}, Opcode: {{ instr[1].opcode }}</strong></p>
<h3>Description</h3>
<p><em>{{ instr[1].description | escape }}</em></p>
{% if instr[1].format != empty %}
  <h3>Instruction Operands</h3>
  <ul>
  {% for operand in instr[1].format %}
  {% assign nops = operand | size %}
    {% if nops == 1 %}
      <li>{{ operand }}</li>
      {{ format | escape }}
    {% else %}
      <li>{{ operand[0] }} or {{ operand[1] }}</li>
    {% endif %}
  {% endfor %}
  </ul>
<p><a href="#top">top of page</a></p>
{% endif %}

{% endfor %}
