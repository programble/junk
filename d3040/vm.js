var VM = function() {
  this.ip = 0;
  this.regs = [0, 0, 0, 0]; // Accumulator, R1, R2, R3
  this.mem = [];
  this.data = [];
}

VM.prototype.step = function() {
  var ir = this.mem[this.ip++];
  if (!ir)
    throw 'No instruction at IP = M' + this.ip;

  switch (ir[0]) {
    case 'INP':
      this.mem[ir[2]] = ir[1];
      break;
    case 'CLA':
      this.regs[0] = 0;
      break;
    case 'MAM':
      this.mem[ir[1]] = this.regs[0];
      break;
    case 'MMR':
      this.regs[ir[2]] = this.mem[ir[1]];
      break;
    case 'MRA':
      this.regs[0] = this.regs[ir[1]];
      break;
    case 'MAR':
      this.regs[ir[1]] = this.regs[0];
      break;
    case 'ADD':
      this.regs[0] = this.regs[ir[1]] + this.regs[ir[2]];
      break;
    case 'SUB':
      this.regs[0] = this.regs[ir[1]] - this.regs[ir[2]];
      break;
    case 'MUL':
      this.regs[0] = this.regs[ir[1]] * this.regs[ir[2]];
      break;
    case 'DIV':
      this.regs[0] = Math.floor(this.regs[ir[1]] / this.regs[ir[2]]);
      break;
    case 'INC':
      this.regs[ir[1]]++;
      break;
    case 'DEC':
      this.regs[ir[1]]--;
      break;
    case 'CMP':
      this.regs[0] = +(this.regs[ir[1]] == this.regs[ir[2]]);
      break;
    case 'JMP':
      this.ip = ir[1];
      break;
    case 'JPZ':
      if (this.regs[0] == 0)
        this.ip = ir[1];
      break;
    case 'JPN':
      if (this.regs[0] != 0)
        this.ip = ir[1];
      break;
    case 'HLT':
      this.ip--;
      return false;
    default:
      throw 'Invalid opcode ' + ir[0] + ' at IP = M' + this.ip;
    }
  return true; // Continue
}

VM.prototype.run = function() {
  while (this.step());
}

VM.parseOperand = function(str) {
  var parsed;
  if (str[0] == 'R')
    parsed = parseInt(str.slice(1));
  else if (str[0] == 'M')
    parsed = parseInt(str.slice(1) - 1);
  else
    parsed = parseInt(str);
  if (isNaN(parsed))
    throw 'Invalid operand ' + str;
  else
    return parsed;
}

VM.prototype.parseCode = function(code) {
  var i = 0,
      vm = this;

  code.trim().toUpperCase().split('\n').forEach(function(line, ln) {
    line = line.split(/\s+/);

    var instruction = [line[0].trim()];
    if (line[1])
      instruction.push(VM.parseOperand(line[1]));
    if (line[2])
      instruction.push(VM.parseOperand(line[2]));

    vm.mem[i++] = instruction;
  });
}

VM.prototype.parseData = function(data) {
  var vm = this;
  data.trim().toUpperCase().split('\n').forEach(function(line, ln) {
    line = line.split(/\s+/);

    var addr = VM.parseOperand(line[0]);
    vm.mem[addr] = +line[1]
    vm.data.push(addr);
  });
}
