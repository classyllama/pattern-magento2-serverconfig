<?php 
header('Cache-Control: private');
# php -r 'echo hash("SHA256", "my_initial_secret") . "\n";'
# curl -sk -D - https://www.exampledomain.com/debug.php?secret=my_initial_secret
$knownSecret = 'eefc91f0b7c36614ac12d8f0860c3a190abafd848cfa86473727da5721239e4f';
$hashedSecret = hash('SHA256', $_GET["secret"]);
if ($knownSecret === $hashedSecret) {
  setcookie("X-Debug", "1", time() + (86400 * 30), "/"); // 86400 = 1 day 
}
?>
<html><body>
<?php 
if (!isset($_COOKIE["X-Debug"])) {
    echo "Debug cookie is NOT set.";
} else {
    echo "Debug cookie is set.";
} 
if ($knownSecret === $hashedSecret) {
    echo "<br/>Setting debug cookie now...";
}
?>
<form action="" method="post">
  <input type="submit" name="Set Debug Cookie"/>
</form>
</body></html>