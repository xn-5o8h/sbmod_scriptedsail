# sbmod_scriptedsail

Description's on the steam workshop too: http://steamcommunity.com/sharedfiles/filedetails/?id=947429656

Tl;dr recoded the hardcoded S.A.I.L. interface in Lua to allow a bit more thingies.

To install, download the archive, and place the "scriptedArtificialIntelligenceLattice" folder in your Starbound/mods/ folder.



I've considered:
- Adding a "ship pet" config slot, but Purchasable Pets already does this.
- Making the config chips be dropped in chests around the universe instead of being craftable, ("Oh cool, I found a new S.A.I.L. chip!", but I didn't wanted to have people who only wanted to customize their S.A.I.L. to be stuck with luck ("hnng, when will I finally find my chip?!"). 
(It'd also require a bit more work from me than a simple recipe file so there's that)
- Putting the S.A.I.L. stations with their corresponding chip A.I. (eg. Felin techstation with Felin A.I. chip), but that felt kind of bloated, and it'd require me to overwrite already-existing items instead of using the patching system
- Using the 3rd chip config slot for S.A.I.L. station customization instead of using yet another item, but it didn't seemed logical to change a physical object from a digital interface. Also, the idea of taking a screwdriver and removing the front pannel of the S.A.I.L. station is pretty cool

Todos: 
- Learn to make code that doesn't suck
- Add the ability to play specific sounds along with dialogs (either once or repeated, and to disable the "beep")
- Make it more modulable, _à la_ ManipulatedMM & Quickbar (eg. people can add their own menus orsomething)
- Something to merge chips together. The implementation should already allow for this, I just haven't gotten around to make something to actually "merge" them, and with 3 slots it's kind of not really useful anyway?
