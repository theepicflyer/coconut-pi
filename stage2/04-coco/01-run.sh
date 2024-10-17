#!/bin/bash

dpkg-deb --build ../../coco coco-scripts.deb && sudo dpkg -i coco-scripts.deb 
rm coco-scripts.deb