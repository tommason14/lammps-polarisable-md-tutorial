# Creating a polarisable MD simulation

> Scripts used here are available [here](https://github.com/PHalat/LAMMPS) and
> [here](https://github.com/agiliopadua/fftool).

Start with

- ac.xyz       
- ch.xyz
- base.in
- il.ff        

from the non polarisable MD setup.

## Atom labels

C15 of ch.xyz has same label as the other methyl carbons. In terms of adding
drude oscillators, they are in different environments (C15 is attached to
N,C,H,H, and the others are attached to N,H,H,H)
This means that the C15 carbon needs a different label (C1 -> C1A).

In il.ff, copy the C1 line and label it as C1A.
No need to change any parameters- the differences are applied later.

You will also change the atom labels in ch.xyz.

### Hydroxyl groups

There have been cases where Drude particles hop from one hydroxyl group to
another. To account for this, a Tang-Toennies damping function ([DOI:10.1063/1.447150](https://aip.scitation.org/doi/10.1063/1.447150)) has been added into lammps, invoked with the `coul/tt` pair style.
These pair coefficients are applied automatically to atom types that include both an 'O' and
a 'H' in the atom label via the `input_polariser` script. So take care when introducing new atom types for
hydroxyls.

## Run through fftool to create a normal non-polarisable MD simulation

```sh
$ fftool 500 ch.xyz 500 ac.xyz -b 62.8
$ packmol < pack.inp
$ fftool 500 ch.xyz 500 ac.xyz -b 62.8 -l
$ cp base.in input_file.lmp
$ transfer_input -psd in.lmp input_file.lmp
```

We need the data file to modify later on.

# Adding drude particles

Parameters of drude particles are given in drude.dff. Each drude particle has a
mass of 0.4 u. This is necessary even though the theory says the particles have
no mass, because if we apply Newtonian physics to a massless particle we'll see
the particles shoot away at a huge velocity- not what we want!

In the drude.dff file, we only give non-hydrogen (heavy) atoms. The
polarisabilites of these particles are the polarisabilites of the atom given plus the
polarisabilites of any hydrogens attached. The atomic polarisabilities (ɑ) can be
found in [DOI: 10.1039/c8cp01677a](http://doi.org/10.1039/c8cp01677a).

For choline acetate:

```sh
# choline 
C1   1.985
C1A  1.662
COL  1.662
N4   1.208
OH   1.467
# acetate 
CO2  1.432
CTA  1.985
O2   1.144
```

where C1 is a methyl carbon, and  1.985  = ɑ(C) + 3 * ɑ(H).

## Commands

Add in the remaining data with:
```
$ drude_constructor drude.dff
```
Warning: This will overwrite the file! If you want to create a new file, use:
```
$ drude_constructor drude.dff cdrude.dff
```
and cdrude.dff will contain the data we need to include later.

# Add drude particles to the standard data file

```
$ polarizer -f cdrude.dff data.lmp pdata.lmp
```

This creates pdata.lmp containing the original system with drude oscillators
applied, as well as a pair-drude.lmp containing pair coefficients to implement
thole damping.

Looking into pdata.lmp, you will see atom labels of C1 DC and C1 DP. These
refer to the drude core, with a mass of the original atom - 0.4, and the drude
particle attached to that atom.  The choice of parameters applied to the drude
particles are found [here](https://lammps.sandia.gov/doc/Howto_drude2.html).

When the polarizer command is run, there is some output, showing commands that
should be added to the input file. We can do this manually, or use the
input_polariser script:

```
$ input_polariser input_file.lmp
```

This takes the pair coefficients from input_file.lmp and adds them to the
pair-drude.lmp file. It then takes the commands that polarizer suggests and
adds them into input_file.lmp. LAMMPS may also complain that too many particles
are surrounding each atom, so the `read_data pdata.lmp extra/special/per/atom 3`
command accounts for this.

# Scaling non-bonding interactions

Now we have additional particles in our simulation to account for changes in
polarisability, the original σ and ε parameters of 6-12 LJ interactions should
be reduced to avoid over-counting the amount of induction between atoms.

To do this, we use a k_ij factor proposed by Padua et al in [DOI:
10.1021/acs.jctc.9b00689](http://doi.org/10.1021/acs.jctc.9b00689):

<img src="https://render.githubusercontent.com/render/math?math=k_%7Bij%7D%20%3D%20%5Cfrac%7BE_%7Bdisp%7D%7D%7BE_%7Bdisp%7D%20%2B%20E_%7Bind%7D%7D">

incorporating dispersion and induction components of intermolecular interaction
energies. These values will be stored in a key.scl file.

These values are calculated using energy decomposition schemes- in the original
paper, SAPT was used. We've used the FMO approach in GAMESS incorporating PIEDA (pair
interaction energy decomposition analysis). Using the FMO approach, the
electrostatic potental between each fragment is calculated using the entire
system, so can only scale interactions between each ion. Using SAPT, interactions involving
just the cations and just the anions were calculated, and more terms are
included in the key.scl file.

The key.scl file should follow the following format:

```sh
e 1:8 9:11 0.6
s * * 0.985
```

Here we are saying to scale the epsilon term between any atoms of type 1-8
(choline) and any atoms of type 9-11 (acetate) by a value of 0.6.  Simulations
performed by Padua et al. tended to give densities slightly higher than
measured experimentally, so the sigma term of every interaction was scaled back
by 1.5% to compensate, giving the `s * * 0.985` line.

If SAPT was used, additional terms can be added, for example:

```sh
# Example scaling file for [c4mim][dca]
e 1:8 12:14 0.61
e 9:11 12:14 0.69
e 1:8 9:11 0.76
s * * 0.985
```

## Commands 

To scale the pair coefficients, run:
```
$ pair_scaler [-k key.scl] [-p pair-drude.lmp] [-s lj/cut/coul/long]
```
Run `pair_scaler` with no arguments to update the pair-drude.lmp file with values from key.scl.

# Run the simulation!

Now you can run the simulation with:
```
$ mpirun -np 8 lmp_mpi -i input.file.lmp
```
