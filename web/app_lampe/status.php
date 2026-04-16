<?php
$gpio_id = "534";
$stat = 0;
if (file_exists("/sys/class/gpio/gpio534/value")) {
    $val = exec("echo $(cat /sys/class/gpio/gpio$gpio_id/value)");
    $direction = exec("echo $(cat /sys/class/gpio/gpio$gpio_id/direction)");
    //var_dump($direction, $val);
    if ($direction == "out" && $val == "0") {
        $stat = 1;
    }
}
echo $stat;
