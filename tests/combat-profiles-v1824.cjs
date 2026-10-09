'use strict';
// Deterministic QA snapshots, NOT accounts guaranteed attainable in a stated
// number of runs. Combat is tested with the actual Game.update() loop.
module.exports=Object.freeze({
 fresh:{damage:0,core:0,income:0,start:0,mastery:1,stars:1,meta:1,units:['sentinel','spark','frost']},
 progressed:{damage:10,core:10,income:6,start:5,mastery:15,stars:3,meta:15,units:['sentinel','spark','frost']},
 veteran:{damage:22,core:18,income:12,start:12,mastery:25,stars:5,meta:45,units:['prism','volt','chrono']},
 gatePrism:{damage:9,core:8,income:5,start:5,mastery:10,stars:2,meta:14,units:['sentinel','spark','frost']},
 gateNova:{damage:12,core:10,income:6,start:7,mastery:15,stars:3,meta:25,units:['sentinel','spark','prism']},
 gateVoltWeak:{damage:18,core:16,income:8,start:10,mastery:20,stars:4,meta:35,units:['prism','nova','ember']},
 gateVoltSynergy:{damage:18,core:16,income:8,start:10,mastery:20,stars:4,meta:35,units:['spark','prism','ember']},
 gateChrono:{damage:20,core:16,income:10,start:11,mastery:20,stars:4,meta:40,units:['prism','ember','volt']}
});
