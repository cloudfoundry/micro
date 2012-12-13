window.initialize_micro_cloudfoundry = (mcf) ->
  mcf ||= new Mcf '/api'

  mcf.configured ->
      $('#configured').show()
      mcf.load_data()
    , ->
      $('#not-configured').show()

  submit = (progress_bar, method, data) ->
    bar = new ProgressBar $(progress_bar)
    bar.start_indeterminate()
    $(this).attr 'disabled', 'disabled'
    mcf[method] data, =>
      mcf.load_data()
      bar.hide()
      $(this).attr 'disabled', null
    , =>
      console.log($("#jasmine_content").size())
      mcf.show_error_pane()
      bar.hide()
      $(this).attr 'disabled', null

  $('#admin-submit').on 'click', ->
    submit.call this, '#admin-bar', 'update_admin',
      email: $('#email').val()
      password: $('#password').val()

  $('#domain-submit').on 'click', ->
    submit.call this, '#domain-bar', 'update_domain',
      name: $('#domain-name').val()
      token: $('#token').val()

  $('#internet-on-submit').on 'click', ->
    submit.call this, '#internet-bar', 'update_micro_cloud', internet_connected: true

  $('#internet-off-submit').on 'click', ->
    submit.call this, '#internet-bar', 'update_micro_cloud', internet_connected: false

  $('#proxy-submit').on 'click', ->
    submit.call this, '#proxy-bar', 'update_micro_cloud', http_proxy: $('#proxy').val()

  $('#shutdown-submit').on 'click', ->
    mcf.shutdown()
    $('#shutdown-modal').modal('hide')

  $('#dhcp').on 'change', ->
    $('.static').prop('disabled', @checked)

  $('.close-alert').on 'click', ->
    $(this).closest('.alert').hide()

  $('#network-submit').on 'click', ->
    submit.call this, '#network-bar', 'update_network',
      name: 'eth0'
      ip_address: $('#ip-address').val()
      netmask: $('#netmask').val()
      gateway: $('#gateway').val()
      nameservers: $('#nameservers').val().split(',')
      is_dhcp: $('#dhcp').is(':checked')
