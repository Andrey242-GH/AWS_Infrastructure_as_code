<?php


$servername = getenv('DB_HOST');
$username = getenv('DB_USER');
$password = getenv('DB_PASS');


$connection = new mysqli($servername, $username, $password);

if ($connection->connect_error) {
    die("Connection failed: " . $connection->connect_error);
} else {
    echo "Connected successfully";
}