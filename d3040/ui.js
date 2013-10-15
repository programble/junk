var vm;

$(function() {
  function error(e, in_reset) {
    var div = $('.alert.hidden').clone().removeClass('hidden');
    div.find('span').html(e);
    $('.alert').first().before(div);
    if (!in_reset)
      reset();
  }

  function reset() {
    try {
      vm = new VM();
      vm.ip = VM.parseOperand($('#inip').val());
      vm.regs[0] = +$('#ina').val();
      vm.regs[1] = +$('#inr1').val();
      vm.regs[2] = +$('#inr2').val();
      vm.regs[3] = +$('#inr3').val();
      vm.parseCode($('#incode').val());
      vm.parseData($('#indata').val());
    } catch (e) {
      error(e, true);
    }
  }

  function output() {
    $('#outip').html('M' + (vm.ip + 1));
    $('#outa').html(vm.regs[0]);
    $('#outr1').html(vm.regs[1]);
    $('#outr2').html(vm.regs[2]);
    $('#outr3').html(vm.regs[3]);
    $('#outdata').empty();
    vm.data.forEach(function(addr) {
      $('<dt>').html('M' + (addr + 1)).appendTo('#outdata');
      $('<dd>').html(vm.mem[addr]).appendTo('#outdata');
    });
  }

  $('#reset').click(function() {
    reset();
    output();
  });

  $('#step').click(function() {
    try {
      vm.step();
    } catch(e) {
      error(e);
    }
    output();
  });

  $('#run').click(function() {
    reset();
    try {
      vm.run();
    } catch(e) {
      error(e);
    }
    output();
  });

  reset();
  output();
});
