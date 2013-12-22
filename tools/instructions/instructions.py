#!/usr/bin/env python
from string import Template
import yaml
import os

HERE = os.path.dirname(__file__)

with open(os.path.join(HERE, '..', '..', 'config', 'instructions.yaml'),
          'r') as itab:
    data = yaml.load(itab.read())
    instructions = data['instructions']
    operands = data['operands']
    alu_opcodes = data['alu_opcodes']

def gen_types(instructions, operands):
    operand_types = 'enum operand_type {\n'
    for name, _ in operands.items():
        operand_types += '\tOPERAND_{0},\n'.format(name.upper())
    operand_types += '};'

    aluops = 'enum alu_opcode {\n'
    for name, val in alu_opcodes.items():
        aluops += '\tALU_OPCODE_{0} = {1},\n'.format(name.upper(), val)
    aluops += '};'

    opcode_types = ''
    for name, definition in instructions.items():
        opcode_types += 'enum {{ OPCODE_{0} = {1} }};\n'.format(name.upper(),
                                                              definition['opcode'])

    with open(os.path.join(HERE, 'types.h.templ'), 'r') as types_templ:
        templ = Template(types_templ.read())
        out = templ.substitute(operand_types = operand_types,
                               opcode_types = opcode_types,
                               alu_opcodes = aluops)
        with open('oldland-types.h', 'w') as types:
            types.write(out)

def gen_operand(name, definition):
    OP_TEMPL = """
        [OPERAND_{name_upper}] = {{
                .name = "{name}",
                .type = OPERAND_{name_upper},
                .pcrel = {pcrel},
                .def = {{
                        .bitpos = {bitpos},
                        .length = {length},
                }},
        }},"""
    fdict = {
        'name': name,
        'name_upper': name.upper(),
        'pcrel': 'true' if 'pcrel' in definition else 'false',
        'bitpos': definition['bitpos'],
        'length': definition['length']
    }
    return OP_TEMPL.format(**fdict)

def gen_meta_operand(name, definition):
    META_OP_TEMPL = """
        [OPERAND_{name_upper}] = {{
                .name = "{name}",
                .type = OPERAND_{name_upper},
                .is_meta = true,
                .meta = {{
                        .ops = (const struct oldland_operand *[]) {{
                                {op_list},
                        }},
                        .nr_ops = {nr_ops},
                }},
        }},"""
    fdict = {
        'name': name,
        'name_upper': name.upper(),
        'nr_ops': len(definition['operands']),
        'op_list': ', '.join(
            ['&operands[OPERAND_{0}]'.format(o.upper()) for o in
            definition['operands']])
    }
    return META_OP_TEMPL.format(**fdict)

def gen_operands(operands):
    ret = 'static const struct oldland_operand operands[] = {'
    for name, definition in operands.items():
        if 'operands' not in definition:
            ret += gen_operand(name, definition)
        else:
            ret += gen_meta_operand(name, definition)
    ret += '\n};'

    return ret

def gen_instruction(name, definition):
    INSTR_TEMPL = """
        [OPCODE_{name_upper}] = {{
                .name = "{name}",
                .class = {class},
                .opcode = OPCODE_{name_upper},
                .constbits = 0x{constbits:08x},
                .nr_operands = {nr_operands},
                .op1 = {{{op1}}},
                .op2 = {{{op2}}},
                .op3 = {{{op3}}},
                .formatsel = {formatsel},
        }}, """
    fdict = {
        'name': name,
        'name_upper': name.upper(),
        'constbits': definition.get('constbits', 0),
        'class': definition['class'],
        'nr_operands': len(definition['format']),
        'formatsel': definition.get('formatsel', -1)
    }
    if len(definition['format']) > 0:
        fdict['op1'] = ', '.join(
            ['&operands[OPERAND_{0}]'.format(o.upper()) for o in
            definition['format'][0]])
    else:
        fdict['op1'] = ''
    if len(definition['format']) > 1:
        fdict['op2'] = ', '.join(
            ['&operands[OPERAND_{0}]'.format(o.upper()) for o in
            definition['format'][1]])
    else:
        fdict['op2'] = ''
    if len(definition['format']) > 2:
        fdict['op3'] = ', '.join(
            ['&operands[OPERAND_{0}]'.format(o.upper()) for o in
            definition['format'][2]])
    else:
        fdict['op3'] = ''
    return INSTR_TEMPL.format(**fdict)

def gen_instructions(instrlist, operands):
    instrs = ''

    for cls in range(0, 4):
        instrs += 'const struct oldland_instruction oldland_instructions_{0}[16] = {{'.format(cls)
        for name, definition in instrlist.items():
            if definition['class'] != cls:
                continue
            instrs += gen_instruction(name, definition)
        instrs += '\n};\n\n'

    with open(os.path.join(HERE, 'instructions.c.templ'), 'r') as instr_templ:
        templ = Template(instr_templ.read())
        out = templ.substitute(instructions = instrs,
                               operands = gen_operands(operands))
        with open('oldland-instructions.c', 'w') as instructionsc:
            instructionsc.write(out)

if __name__ == '__main__':
    gen_types(instructions, operands)
    gen_instructions(instructions, operands)
