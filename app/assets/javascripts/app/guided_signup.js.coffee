window.signUp = {
	current_step: 1
}

window.showStep = (step = 1) ->
	$('.tab-content').children().removeClass('active')
	$('.progress-bar-label').removeClass('active')
	switch step
		when 1
			$('#step-one').addClass('active')
			$('.progress-bar-label.one-label').addClass('active');
			setProgress(1)
		when 2
			$('#step-two').addClass('active')
			$('.progress-bar-label.two-label').addClass('active');
			setProgress(17)
		when 3
			$('#step-three').addClass('active')
			$('.progress-bar-label.three-label').addClass('active');
			setProgress(31)
		when 4
			$('#step-four').addClass('active')
			$('.progress-bar-label.four-label').addClass('active');
			setProgress(45)
		when 5
			$('#step-five').addClass('active')
			$('.progress-bar-label.five-label').addClass('active');
			setProgress(60)
		when 6
			$('#step-six').addClass('active')
			$('.progress-bar-label.six-label').addClass('active');
			setProgress(74)
		when 7
			$('#step-seven').addClass('active')
			$('.progress-bar-label.seven-label').addClass('active');
			setProgress(100)


if $('#progress-bar').length
	window.progressBar = $('#progress-bar')[0]
	window.steps = $('.progress').find('.step')

	window.setProgress = (progress = 0) ->
		$(window.progressBar).css 'width', "#{progress}%"
		for step in window.steps
			if $(step).offset().left > $(window.progressBar).parent().width() * progress/100
				$(step).removeClass('primary-color').addClass('no-color')
			else
				$(step).removeClass('no-color').addClass('primary-color')
			1
