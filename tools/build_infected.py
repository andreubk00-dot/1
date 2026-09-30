#!/usr/bin/env python3
import os,sys
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import infected3d
project=os.path.abspath(os.path.join(os.path.dirname(__file__),'..'))
infected3d.build_all(project)
print('built infected_walk_v12.png + infected_attack_v12.png')
