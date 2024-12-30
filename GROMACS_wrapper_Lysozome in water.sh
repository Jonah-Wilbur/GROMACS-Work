#!/usr/bin/bash
ID=$11
MDP=$3
SOL=${SOL:-13}

get() {
    echo "#######################################################"
    echo "Getting PDB file"
    echo "#######################################################"
    wget -O $ID.pdb "https://files.rcsb.org/download/$ID.pdb"
    grep -v HOH $ID.pdb > ${ID}_clean.pdb
}

import() {
    echo "#######################################################"
    echo "Importing PDB file"
    echo "#######################################################"
    gmx pdb2gmx -f ${ID}_clean.pdb -o ${ID}_processed.gro -water spce -ff oplsaa -p ${ID}_topol.top
}

box() {
    echo "#######################################################"
    echo "Creating box"
    echo "#######################################################"   
    gmx editconf -f ${ID}_processed.gro -o ${ID}_newbox.gro -c -d 1.0 -bt cubic
}

solvate() {
    gmx solvate -cp ${ID}_newbox.gro -cs spc216.gro -o ${ID}_solv.gro -p ${ID}_topol.top
}

ions() {
    echo $1 | gmx genion -s ions.tpr -o ${ID}_solv_ions.gro -p ${ID}_topol.top -pname NA -nname CL -neutral
}

energy_minimization() {
    gmx grompp -f minim.mdp -c ${ID}_solv_ions.gro -p ${ID}_topol.top -o ${ID}_em.tpr
    gmx mdrun -v -deffnm ${ID}_em
}

equilibration() {
    gmx grompp -f nvt.mdp -c ${ID}_em.gro -r ${ID}_em.gro -p ${ID}_topol.top -o ${ID}_nvt.tpr
    gmx mdrun -deffnm ${ID}_nvt
    gmx grompp -f npt.mdp -c ${ID}_nvt.gro -r ${ID}_nvt.gro -t ${ID}_nvt.cpt -p ${ID}_topol.top -o ${ID}_npt.tpr
    gmx mdrun -deffnm ${ID}_npt
}

production() {
    gmx grompp -f md.mdp -c ${ID}_npt.gro -t ${ID}_npt.cpt -p ${ID}_topol.top -o ${ID}_md_0_1.tpr
    gmx mdrun -deffnm ${ID}_md_0_1 -nb gpu
}

data_collection(){
    gmx energy -f ${ID}_em.edr -o potential.xvg
}

all() {
        get
        import
        box
        solvate
        ions ${SOL}
        energy_minimization
        equilibration
        production
}
case $2 in
    i)
        import
        ;;
    em)
        energy_minimization
        ;;
    *)
        eval $2
        ;;

esac 
