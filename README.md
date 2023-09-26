# CalcAtk-IronmonExtension
Estimate an enemy Pokémon's attacking stat using a reverse damage formula calculation. This extension is for the Gen 3 Ironmon Tracker

The formula used is derived from the Gen 3 decomp [CalculateBaseDamage Formula](https://github.com/pret/pokefirered/blob/23dd3372467922069777addeb37b220f2e25d7e5/src/pokemon.c#L2385-L2649).

## Requirements
- [Ironmon-Tracker v8.3.0](https://github.com/besteon/Ironmon-Tracker) or higher

## Download & Install
1) Download the [latest release](https://github.com/UTDZac/CalcAtk-IronmonExtension/releases/latest) of this extension from the GitHub's Releases page
2) If you downloaded a `.zip` file, first extract the contents of the `.zip` file into a new folder
3) Put the extension file(s) in the existing "**extensions**" folder found inside your Tracker folder
   - The file(s) should appear as: `[YOUR_TRACKER_FOLDER]/extensions/CalcAtk.lua`
4) On the Tracker settings menu (click the gear icon on the Tracker window), click the "**Extensions**" button
5) In the Extensions menu, enable "**Allow custom code to run**" (if it is currently disabled)
6) Click the "**Install New**" button at the bottom to check for newly installed extensions
   - If you don't see anything in the extensions list, double-check the extension files are installed in the right location. Refer to the [Tracker wiki documentation](https://github.com/besteon/Ironmon-Tracker/wiki/Tracker-Add-ons#install-and-setup-1) if you need additional help
7) Click on the "**Attacking Damage Calc.**" extension button to view the extension and turn it on

## How to use
While in battle, after you take damage, simply click the "**Last Damage: #**" at the bottom to open the extension tool. You can also access the tool through Settings > Extensions > Attacking Damage Calc. > Options.

![image](https://github.com/UTDZac/CalcAtk-IronmonExtension/assets/4258818/a57929d1-798f-4507-9d6d-ee058e27d353)

When the tool opens, the Tracker will automatically populate the damage calc formula with information from the enemy Pokémon, the move it used, and your Pokémon's defensive stat.

![image](https://github.com/UTDZac/CalcAtk-IronmonExtension/assets/4258818/861b5560-33bb-4daf-ab73-30f027d0bf91)

#### Attack Stat Estimates
- The **low-estimate** for the attacking stat is shown as the top value in red font.
- The **high-estimate** for the attacking stat is shown at the bottom value in green font.
- Click on the SWORD icon at the top to re-calculate if needed
- Click the **(Clear)** text-button to clear out all variables

#### Adjust Variables
- **Enemy Pokémon Lv**: The level of the Pokémon you are currently fighting against
- **Damage**: The amount of damage the enemy Pokémon dealt to your Pokémon
- **Your DEF/SPD**: Your Pokémon's defense stat or special defense stat; use **DEF** for Physical moves and **SPD** for Special moves
- **Move Power**: The power of the move that dealt damage to your Pokémon
- **Move Effectiveness**: The move type effectiveness of the move damaing your Pokémon; e.g. **0.25**, **0.5**, **1.0**, **2.0**, or **4.0**
- **Other Multiplier(s)**: If you need to further adjust the calculation based on other factors, such as Flash Fire or Helping Hand, do that here
- **[ ] STAB**: Check this box if the move's type matches one of the types of the enemy Pokémon; results in a **1.5x** multipler
- **[ ] Crit**: Check this box if the move did critical damage; results in a **2.0x** multiplier
- **[ ] Weather**: Check this box if the currently active weather boosts the move's damage (Fire in the Sun / Water in the Rain); results in a **1.5x** multiplier
- **[ ] Burned**: Check this box if the enemy Pokémon is using a Physical move AND is also burned; results in a **0.5x** multipler
- **[ ] Screen/Reflect**: Check this box if your Pokémon has Light Screen or Reflect active AND they're hit by a Special or Physical move respectively; results in a **0.5x** multipler

