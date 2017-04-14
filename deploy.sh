#! /bin/bash

hugo

scp -r public/ thorub2@thomasruble.com:~/thomasruble.com/
