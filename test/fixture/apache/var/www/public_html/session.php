<?php
	session_start();
	$_SESSION['integer'] = 123;
	$_SESSION['float'] = 12345.67890;
	$_SESSION['string'] = '@string:#\$£';
	session_write_close();
	var_dump($_SESSION);
