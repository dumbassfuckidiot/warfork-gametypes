
int POWERUPS_randomInteger(int min, int max) { return min + rand() % (max - min + 1); }

array<int> POWERUPS_teamAlivePlayerList( int teamNum ) {
    Team @team = @G_GetTeam( teamNum );

    array<int> playerList;
    for ( int i = 0; @team.ent( i ) != null; i++ )
    {
        if ( !team.ent( i ).isGhosting() )
        playerList.insertLast( team.ent( i ).playerNum );
    }
    return playerList;
  };

int POWERUPS_randomPlayerNumTeam( int teamNum ) {
    array<int> playerList = POWERUPS_teamAlivePlayerList( teamNum );
    return playerList[POWERUPS_randomInteger( 0, playerList.length() - 1 )];
};

const uint POWERUPRNGTYPE_NONE = 1;
const uint POWERUPRNGTYPE_MULTIPLIER = 2;
const uint POWERUPRNGTYPE_PERCENT = 3;
const uint POWERUPRNGTYPE_NUMBER = 4;
const uint POWERUPRNGTYPE_INTEGER = 5;

const uint KEY_FORWARD  =   0;
const uint KEY_BACK     =   1;
const uint KEY_LEFT     =   2;
const uint KEY_RIGHT    =   3;
const uint KEY_ATTACK   =   4;
const uint KEY_JUMP     =   5;
const uint KEY_CROUCH   =   6;
const uint KEY_SPECIAL  =   7;
const uint KEY_TOTAL    =   8;

const uint POWERUPID_NONE = 0;
const uint POWERUPID_SWAP = 1;
const uint POWERUPID_INSTA = 2;
const uint POWERUPID_VAMPIRE = 3;
const uint POWERUPID_MAXSPEED = 4;
const uint POWERUPID_DASH = 5;
const uint POWERUPID_JUMP = 6;
const uint POWERUPID_EXTRADMG = 7;
const uint POWERUPID_JETPACK = 8;
const uint POWERUPID_EXTRAKB = 9;
const uint POWERUPID_LAUNCH = 10;
const uint POWERUPID_INVISIBILITY = 11;
const uint POWERUPID_QUAD = 12;
const uint POWERUPID_IMMORTALITY = 13;
const uint POWERUPID_PULL_TOWARDS = 14;
const uint POWERUPID_INFINITE_AMMO = 15;


const uint maxPowerupID = 15;


int KB_GB = 50;
int KB_MG = 10;
int KB_RG = 7;
int KB_GL = 100;
int KB_RL = 100;
int KB_PG = 20;
int KB_LG = 14;
int KB_EB = 80;

int kb_amount_weapon(int weap) {
    switch (weap)
    {
        case WEAP_GUNBLADE: return KB_GB;
        case 2: return KB_MG;
        case 3: return KB_RG;
        case 4: return KB_GL;
        case 5: return KB_RL;
        case 6: return KB_PG;
        case 7: return KB_LG;
        case 8: return KB_EB;

        default: return 0;
    }

};

bool isKeyPressed(Client @client, uint key) {
    return ( int(client.pressedKeys) & (1<<key) == (1<<key) );
};

// const uint POWERUP_INVISIBLE_PMFEATS = PMFEAT_DEFAULT & ~(
//     PMFEAT_CROUCH
// );

const uint POWERUP_JETPACK_PMFEATS = PMFEAT_DEFAULT & ~(
    PMFEAT_CROUCH |
    PMFEAT_JUMP |
    PMFEAT_DASH |
    PMFEAT_WALLJUMP
);


array<cPowerUp@> powerups;
array<cPowerUp@> selectablePowerups;


array<cPowerUp@> powerUp(maxClients);

String formatRand(uint randomNumType, float rand) {
    String msg = "";
    switch (randomNumType)
    {
        case POWERUPRNGTYPE_MULTIPLIER:
        msg += StringUtils::FormatFloat(rand, "0", 1, 1) + "x";
            break;

        case POWERUPRNGTYPE_PERCENT:
        msg += StringUtils::FormatFloat(rand * 100, "0", 1, 0) + "%";
            break;

        case POWERUPRNGTYPE_NUMBER:
        msg += StringUtils::FormatFloat(rand, "0", 1, 1);
            break;

        case POWERUPRNGTYPE_INTEGER:
        msg += StringUtils::FormatFloat(rand, "0", 1, 0);
            break;

        default:
            break;
    }
    return msg;
}

class cPowerUp {
    uint powerupID;

    uint randomNumberType;

    float randMin;
    float randMax;
    float rand;
    float rand2;
    bool useRand2;

    uint cooldownLength;
    uint cooldownTime;

    bool ability;

    uint abilityLength;
    uint abilityTimeEnd;

    uint effects;

    String name;
    String shortName;
    String color;
    String description;
    String shortDescription;

    cPowerUp(uint id, uint randNumType, float min, float max, bool useR2, float cdown, float abilLen, const String &n, const String &sn, const String &c, const String &d, const String &sd) {
        powerupID = id;
        randomNumberType = randNumType;

        randMin = min;
        randMax = max;
        rand = 0.0f;
        rand2 = 0.0f;
        useRand2 = useR2;

        cooldownLength = floor( cdown * 1000 );
        cooldownTime = levelTime + cooldownLength;

        ability = false;
        abilityLength = floor( abilLen * 1000 );
        abilityTimeEnd = 0;

        effects = 0;

        name = n;
        shortName = sn;
        color = c;
        description = d;
        shortDescription = sd;
    }

    void init (Entity @ent) {
        if (this.randomNumberType != POWERUPRNGTYPE_NONE) {
            this.rand = brandom( this.randMin, this.randMax );
            this.rand2 = brandom( this.randMin, this.randMax );
          }
        else {
            this.rand = 0.0f;
            this.rand2 = 0.0f;
        }
        // G_Print(ent.client.name + " " + this.name + " " + this.rand + " " + (this.useRand2  ? this.rand2 : "") + "\n");
        // G_Print(ent.client.name + " " + this.powerupMessage() + "\n");
        // G_CenterPrintMsg(ent, this.color + this.name + " " + this.rand + " " + this.rand2 );

        if (this.powerupID != POWERUPID_NONE) {
            G_PrintMsg(ent, this.powerupMessage() + "\n" );
            G_CenterPrintMsg(ent, this.powerupMessage() );
        }
        if ( maxClients < 120 ) {               // MAX_GENERAL = 128, MAX_CLIENTS = 256
            G_ConfigString( CS_GENERAL + 2 + ent.playerNum, this.statMessage() );
            ent.client.setHUDStat( STAT_MESSAGE_SELF, CS_GENERAL + 2 + ent.playerNum );
          }

    }

    String statMessage(bool short = false) {
        String msg = this.color + (short ? this.shortName : this.name ) + S_COLOR_WHITE;
        msg += StringUtils::Format(this.shortDescription, formatRand(this.randomNumberType, this.rand), formatRand(this.randomNumberType, this.rand2));
        msg += S_COLOR_WHITE;
        return msg;
    };

    String powerupMessage() {
        String msg = statMessage() + "\n";
        msg += StringUtils::Format(this.description, formatRand(this.randomNumberType, this.rand), formatRand(this.randomNumberType, this.rand2));
        msg += S_COLOR_WHITE;
        return msg;
    };

    void select(Entity @ent) { }
    void endRound(Entity @ent) { }

    void think(Entity @ent) { }
    void kill(Entity @ent, const String &in args = "") { }
    void dmg(Entity @ent, const String &in args = "") { }

    void tookdmg(Entity @ent, const String &in args = "") { }

    void classAction(Entity @ent) { }

    bool checkCooldown(Entity @ent) {
        if (ent.isGhosting())
            return false;
        if (this.cooldownTime > levelTime) {
            G_PrintMsg(ent, StringUtils::Format( (this.color + this.name + S_COLOR_WHITE + " is on cooldown for %s more seconds\n"),
            StringUtils::FormatFloat(float(this.cooldownTime - levelTime)/1000.0f, "0", 1, 1)));
            return false;
        }
        if (this.cooldownLength != 0.0f)
            this.cooldownTime = levelTime + this.cooldownLength;
        return true;

    }

    float getCooldownFloat() {
        if ( this.cooldownLength <= 0.0f )
            return 0.0f;
        float cooldown = ( float((levelTime + this.cooldownLength) - this.cooldownTime) ) / this.cooldownLength;
        if (ability)
            cooldown = 1.0f - ( float((levelTime + this.abilityLength) - this.abilityTimeEnd) ) / this.abilityLength;

        if (cooldown <= 0.0f)
            cooldown = 0.0f;
        if (cooldown >= 1.0f)
            cooldown = 1.0f;
        return cooldown;
    };
    float getStatFloat() {
        return getCooldownFloat();
    };

};


class cPowerUpNone : cPowerUp {
    cPowerUpNone() {
        super(
            POWERUPID_NONE,

            POWERUPRNGTYPE_NONE,
            0.0f, 0.0f, false,
            0.0f, 0.0f,
            "", "",
            S_COLOR_WHITE,
            "", ""
        );
    }
}

class cPowerUpSwap : cPowerUp {
    cPowerUpSwap() {
        super(
            POWERUPID_SWAP,

            POWERUPRNGTYPE_NONE,
            0.0f, 0.0f, false,
            10.0f, 0.0f,
            "Position Swap", "Swap",
            S_COLOR_ORANGE,
            "Swap positions of yourself and a player on the enemy team", ""
        );
    }


    void select(Entity @ent) override {
        POWERUP_setUpClassaction( @ent, "Swap");
    }

    void classAction(Entity @ent) override {

        if (caRound.state != CA_ROUNDSTATE_ROUND)
            return;
        if (ent.health <= 0)
            return;
        if (!checkCooldown(@ent))
            return;

        int enemyTeam = ent.team == TEAM_ALPHA ? TEAM_BETA : TEAM_ALPHA;
        if (POWERUPS_teamAlivePlayerList(enemyTeam).length() == 0)
            return;
        Entity @targetEnt = G_GetEntity(POWERUPS_randomPlayerNumTeam(enemyTeam) + 1);

        Vec3 initiatorOrigin = ent.origin;
        Vec3 initiatorAngles = ent.angles;
        Vec3 initiatorVelocity = ent.velocity;
        Vec3 initiatorAVelocity = ent.avelocity;

        Vec3 targetOrigin = targetEnt.origin;
        Vec3 targetAngles = targetEnt.angles;
        Vec3 targetVelocity = targetEnt.velocity;
        Vec3 targetAVelocity = targetEnt.avelocity;

        ent.origin = targetOrigin;
        ent.angles = targetAngles;
        ent.velocity = targetVelocity;
        ent.avelocity = targetAVelocity;

        targetEnt.origin = initiatorOrigin;
        targetEnt.angles = initiatorAngles;
        targetEnt.velocity = initiatorVelocity;
        targetEnt.avelocity = initiatorAVelocity;


        G_PrintMsg(ent, "You swapped with " + targetEnt.client.name + "\n");
        G_PrintMsg(targetEnt, ent.client.name + S_COLOR_WHITE + " swapped with you" + "\n");
        G_CenterPrintMsg(ent, "You swapped with " + targetEnt.client.name );
        G_CenterPrintMsg(targetEnt, ent.client.name + S_COLOR_WHITE + " swapped with you" );
        ent.respawnEffect();
        targetEnt.respawnEffect();
    }
}

class cPowerUpInsta : cPowerUp {
    cPowerUpInsta() {
        super(
            POWERUPID_INSTA,
            POWERUPRNGTYPE_NONE,
            0.0f, 0.0f, false,
            0.0f, 0.0f,
            "Instagib", "Insta",
            S_COLOR_MAGENTA,
            "You frag people in one hit, but you have low health", ""
        );
    }

    void select(Entity @ent) override {
        Team @team = @G_GetTeam( ent.team == TEAM_ALPHA ? TEAM_BETA : TEAM_ALPHA );
        int enemiesAlive = 0;
        for ( int i = 0; @team.ent( i ) != null; i++ )
        {
            if ( !team.ent( i ).isGhosting() )
                enemiesAlive++;
        }

        ent.client.inventoryClear();
        ent.client.inventorySetCount( WEAP_GUNBLADE, 1 );
        ent.client.inventorySetCount( WEAP_INSTAGUN, 1 );
        ent.client.inventorySetCount( AMMO_INSTAS, enemiesAlive );
        ent.client.armor = 0;
        ent.health = 75;
        ent.client.selectWeapon(-1);
    }
    void dmg(Entity @ent, const String &in args = "" ) override {
        Entity @victim = @G_GetEntity( args.getToken( 0 ).toInt() );
        // float damage = args.getToken( 1 ).toFloat();
        cPowerUp @pwr = @powerUp[victim.playerNum];
        if ( @victim.client != null && pwr.powerupID != POWERUPID_IMMORTALITY && !pwr.ability )
            victim.health -= 9999;
      // make sure they die
    }


}


class cPowerUpVampire : cPowerUp {
    cPowerUpVampire() {
        super(
            POWERUPID_VAMPIRE,
            POWERUPRNGTYPE_PERCENT,
            0.1f, 1.0f, false,
            0.0f, 0.0f,
            "Vampire", "Vamp",
            S_COLOR_GREY,
            "You steal %s of the damage you do",
            " - %s"
        );
    }

    void select(Entity @ent) override {
        ent.health = 250;
        ent.maxHealth = 500;

        ent.client.armor = 0;

    };
    void dmg(Entity @ent, const String &in args = "" ) override {
        if (ent.health <= 0)
            return;

        float damage = args.getToken( 1 ).toFloat();
        ent.health += (damage * this.rand);
        if (ent.health >= ent.maxHealth)
            ent.health = ent.maxHealth;
    }
}

class cPowerUpMaxSpeed : cPowerUp {
    cPowerUpMaxSpeed() {
        super(
            POWERUPID_MAXSPEED,
            POWERUPRNGTYPE_MULTIPLIER,
            1.5f, 3.0f, false,
            0.0f, 0.0f,
            "Acceleration", "Accel",
            S_COLOR_CYAN,
            "You accelerate %s faster",
            " - %s"
        );
    }

    void select(Entity @ent) override {
        ent.client.pmoveMaxSpeed = ( 320 * this.rand );
    }
}

class cPowerUpDashSpeed : cPowerUp {
    cPowerUpDashSpeed() {
        super(
            POWERUPID_DASH,
            POWERUPRNGTYPE_MULTIPLIER,
            1.5f, 2.0f, false,
            0.0f, 0.0f,
            "Dash Speed", "Dash",
            S_COLOR_CYAN,
            "Your dash is %s faster",
            " - %s"
          );
      }

    void select(Entity @ent) override {
        ent.client.pmoveDashSpeed = ( 450 * this.rand );
      }
}

class cPowerUpJumpSpeed : cPowerUp {
    cPowerUpJumpSpeed() {
        super(
            POWERUPID_JUMP,
            POWERUPRNGTYPE_MULTIPLIER,
            0.5f, 2.0f, false,
            0.0f, 0.0f,
            "Jump Height", "Jump",
            S_COLOR_CYAN,
            "You jump %s as high",
            " - %s"
          );
      }

    void select(Entity @ent) override {
        ent.client.pmoveJumpSpeed = ( 280 * this.rand );
      }
}

class cPowerUpExtraDamage : cPowerUp {
    cPowerUpExtraDamage() {
        super(
            POWERUPID_EXTRADMG,
            POWERUPRNGTYPE_MULTIPLIER,
            1.25f, 2.0f, false,
            0.0f, 0.0f,
            "Extra Damage", "+DMG",
            S_COLOR_RED,
            "You deal %s more damage",
            " - %s"
        );
    }
    void dmg(Entity @ent, const String &in args = "" ) override {

        Entity @victim = @G_GetEntity( args.getToken( 0 ).toInt() );
        float damage = args.getToken( 1 ).toFloat();
        if (victim.client == null)
            return;
        if (damage > victim.health + victim.client.armor )
            return;

        cPowerUp @pwr = @powerUp[ent.playerNum];
        if ( @victim.client != null && pwr.powerupID != POWERUPID_IMMORTALITY && !pwr.ability ) {
            if (victim.client.armor > 0.0f) {
                victim.client.armor -= damage;
                if (victim.client.armor < 0.0f)
                    damage = -(victim.client.armor);
                else
                    damage = 0;
            }
            victim.health -= damage;
        };




    }
};

class cPowerUpJetpack : cPowerUp {
    cPowerUpJetpack() {
        super(
            POWERUPID_JETPACK,
            POWERUPRNGTYPE_NUMBER,
            1.0f, 3.0f, false,
            0.0f, 0.0f,
            "Jetpack", "JP",
            S_COLOR_GREEN,
            "You can fly by holding jump and go down by holding crouch.",
            " - %s"
          );
    }

    float fuelMax = 100.0f;
    float fuel = fuelMax;
    bool outOfFuel = false;

    void select(Entity @ent) override {
        ent.client.pmoveFeatures = POWERUP_JETPACK_PMFEATS;
        this.fuel = this.fuelMax;
    };

    float getStatFloat() override {
        return this.fuel / this.fuelMax;
    };

    void think(Entity @ent) override {
        Vec3 newVelocity = ent.velocity;
        if ( fuel > 0.0f && !outOfFuel ) {
            if ( isKeyPressed(ent.client, KEY_JUMP) ) {

                if (ent.groundEntity != null) {
                    Vec3 newOrigin = ent.origin;
                    newOrigin.z += 0.5f;
                    ent.origin = newOrigin;
                }

                this.fuel -= 10 * (frameTime * 0.001f);


                newVelocity.z += (this.rand + 15.0f);
                ent.velocity = newVelocity;
            }
            if ( isKeyPressed(ent.client, KEY_CROUCH ) ) {
                Vec3 newVelocity = ent.velocity;
                newVelocity.z -= this.rand;
                ent.velocity = newVelocity;
                this.fuel -= 5 * (frameTime * 0.001f);

            }
            if ( isKeyPressed(ent.client, KEY_SPECIAL ) ) {
                if (ent.groundEntity != null) {
                    Vec3 newOrigin = ent.origin;
                    newOrigin.z += 0.5f;
                    ent.origin = newOrigin;

                }

                Vec3 fwd, right, up;
                ent.angles.angleVectors(fwd, right, up);
                fwd.z = 0;
                fwd.normalize();

                float speed = newVelocity.length();
                float minspeed = ( 450 * ( this.rand / this.randMax ) );
                float maxspeed = 450 + 450 * this.rand;
                if ( speed < minspeed )
                    speed = minspeed;
                else if ( speed > maxspeed )
                    speed = maxspeed;
                else
                    speed += minspeed / (450 / 3);
                newVelocity.x = fwd.x * speed;
                newVelocity.y = fwd.y * speed;
                newVelocity.z += (this.rand + 15.0f);
                this.fuel -= 15 * (speed / 450) * (frameTime * 0.001f);

            }
        }
        if (ent.groundEntity == null) {
            ent.client.pmoveMaxSpeed = 500;
        } else {
            ent.client.pmoveMaxSpeed = 240;
        }

        if (this.fuel < fuelMax && ent.groundEntity != null ) {
            if (!outOfFuel)
                this.fuel += 25 * (frameTime * 0.001f);
            else
                this.fuel += 15 * (frameTime * 0.001f);

        }

        if (this.fuel > fuelMax) {
            this.fuel = fuelMax;
            if (this.outOfFuel)
                this.outOfFuel = false;
        }

        if (this.fuel < this.fuelMax / 10 && !outOfFuel) {
            G_CenterPrintMsg(ent, S_COLOR_RED + "You are low on fuel!" );
        }

        if (this.fuel < 0) {
            this.fuel = 0;
            this.outOfFuel = true;
            G_CenterPrintMsg(ent, S_COLOR_RED + "You are out of fuel!" );
        }

        ent.velocity = newVelocity;

    }

}

class cPowerUpExtraKnockback : cPowerUp {
    cPowerUpExtraKnockback() {
        super(
            POWERUPID_EXTRAKB,
            POWERUPRNGTYPE_MULTIPLIER,
            1.25f, 2.5f, false,
            0.0f, 0.0f,
            "Extra Knockback", "+KB",
            S_COLOR_RED,
            "You deal %s more knockback to enemies",
            " - %s"
          );
    }

    void dmg(Entity @ent, const String &in args = "" ) override {

        Entity @victim = @G_GetEntity( args.getToken( 0 ).toInt() );
        float damage = args.getToken( 1 ).toFloat();
        if (victim.client == null)
            return;
        if (damage > victim.health + victim.client.armor )
            return;
        if (kb_amount_weapon(ent.weapon) == 0)
            return;
        Vec3 dir, b, c;
        Vec3 angles = ent.angles;
        Vec3 VictimOrigin = victim.origin;
        angles.z += ent.viewHeight;
        angles.angleVectors( dir, b, c );
        VictimOrigin.z += 0.25;
        victim.origin = VictimOrigin;
        victim.sustainDamage( @ent, @ent, dir, 0, kb_amount_weapon(ent.weapon) * (this.rand - 1.0f), 0, MOD_BARREL);

    }

    // void think(Entity @ent) override {
    //     array<String> projectile_classnames = {"rocket", "grenade", "plasma", "gunblade_blast"};
    //     // ent.client.inventorySetCount(POWERUP_QUAD, 10);
    //     // 1108082688 - 1133903872
    //     // 1108082688 - 1120403456
    //     for ( int i = 0; i < projectile_classnames.length(); i++ )
    //     {
    //         array<Entity @> @ents = G_FindByClassname( projectile_classnames[i] );
    //
    //         for ( int j = 0; j < ents.length(); j++ ) {
    //             if (@ents[j].owner != @ent)
    //                 continue;
    //             if (ents[j].target == "ExtraKB")
    //                 continue;
    //             Vec3 origin = ent.origin;
    //             origin.z += ent.viewHeight;
    //             Entity @newEnt = null;
    //             // origin, angles, speed, radius, damage, knockback, stun, owner
    //             if (ents[j].classname == "rocket")
    //                 @newEnt = @G_FireRocket(ents[j].origin, ents[j].angles, 1150, 125, 80, 100 * this.rand, 1250, @ent );
    //             else if (ents[j].classname == "grenade")
    //                 G_Print(ents[j].projectileMinKnockback + "\n");
    //             else if (ents[j].classname == "plasma")
    //                 @newEnt = @G_FirePlasma(ents[j].origin, ents[j].angles, 2500, 45, 15, 20 * this.rand, 200, @ent);
    //             else if (ents[j].classname == "gunblade_blast")
    //                 @newEnt = @G_FireBlast(ents[j].origin, ents[j].angles, 3000, 70, 35, 90 * this.rand, 0, @ent);
    //
    //
    //             if (@newEnt == null)
    //                 continue;
    //             newEnt.target = "ExtraKB";
    //             ents[j].freeEntity();
    //
    //         }
    //     }
    // };

  };

class cPowerUpLaunch : cPowerUp {
    cPowerUpLaunch() {
        super(
            POWERUPID_LAUNCH,
            POWERUPRNGTYPE_MULTIPLIER,
            1.0f, 2.0f, true,
            10.0f, 0.0f,
            "Boom!", "Boom",
            S_COLOR_ORANGE,
            "You make a large explosion for people in close proximity to you",
            " - Range: %s Damage: %s"
          );
      }

    void select(Entity @ent) override {
        POWERUP_setUpClassaction( @ent, "Boom!");
    }

    void classAction(Entity @ent) override {
        if (!checkCooldown(@ent))
            return;
        ent.splashDamage( @ent, this.rand * 500, this.rand2 * 37.5f, this.rand * 400.0f, 0, MOD_BARREL);
        ent.explosionEffect(this.rand * 100);
    }
};

class cPowerUpInvisibility : cPowerUp {
    cPowerUpInvisibility() {
        super(
            POWERUPID_INVISIBILITY,
            POWERUPRNGTYPE_NUMBER,
            0.2f, 1.2f, false,
            0.0f, 0.0f,
            "Invisibility", "Invis",
            S_COLOR_WHITE,
            "You are invisibile while you aren't shooting or in air.\nYou will be visible for %s seconds after you stop shooting or touch the ground.", ""
          );
      }

    void select(Entity @ent) override {
        ent.svflags |= SVF_ONLYTEAM ;
        // ent.client.pmoveFeatures = POWERUP_INVISIBLE_PMFEATS;

        // ent.client.inventoryClear();
        // ent.client.inventorySetCount( WEAP_GUNBLADE, 1 );
        // ent.client.inventorySetCount( AMMO_GUNBLADE, 1 );
        // ent.client.selectWeapon(-1);

        ent.client.armor = 0;

        this.abilityLength = (this.rand * 1000);

    }


    void think(Entity @ent) override {
        bool wantsEnableVisibility = ( isKeyPressed(ent.client, KEY_ATTACK ) ) || ent.groundEntity == null;
        if ( wantsEnableVisibility ) {
            // is visible
            this.ability = false;
            ent.effects &= ~EF_SHELL;
            ent.svflags &= ~SVF_ONLYTEAM;
            this.abilityTimeEnd = levelTime + this.abilityLength;

        }
        else if (this.abilityTimeEnd < levelTime)
        {
            // is invisible
            this.ability = true;
            ent.svflags |= SVF_ONLYTEAM;
            ent.effects |= EF_SHELL;

        }

        if ( maxClients < 120 ) {
            String HiddenString = (S_COLOR_CYAN + "Hidden");
            String VisibleString = (S_COLOR_RED + "Visible");
            if ( !wantsEnableVisibility && this.abilityTimeEnd >= levelTime ) {
                float secondsUntilEnd = ( ( float(this.abilityTimeEnd) - float(levelTime) ) / 1000);
                String secondsUntilEndStr = StringUtils::FormatFloat(secondsUntilEnd, "0", 1, 1);
                VisibleString += " " + secondsUntilEndStr + "s";
            }
            G_ConfigString( CS_GENERAL + 2 + ent.playerNum, this.statMessage() + " - " + (this.ability ? HiddenString : VisibleString ) );
        }

    }

    void tookdmg(Entity @ent, const String &in args = "" ) override {
        this.ability = false;
        ent.effects &= ~EF_SHELL;
        ent.svflags &= ~SVF_ONLYTEAM;
        this.abilityTimeEnd = levelTime + (this.abilityLength * 2);
    };
};

class cPowerUpQuad : cPowerUp {
    cPowerUpQuad() {
        super(
            POWERUPID_QUAD,
            POWERUPRNGTYPE_INTEGER,
            3.0f, 10.0f, false,
            10.0f, 0.0f,
            "Quad Damage", "Quad",
            S_COLOR_ORANGE,
            "Your damage is quadrupled for %s seconds",
            " - %s seconds"
          );
      }

    void select(Entity @ent) override {
        POWERUP_setUpClassaction( @ent, "Activate Quad Damage");
    }

    void classAction(Entity @ent) override {
        if (!checkCooldown(@ent))
        return;
        this.abilityLength = (this.rand * 1000);
        this.abilityTimeEnd = levelTime + this.abilityLength;
        this.cooldownTime = levelTime + this.cooldownLength + abilityLength;
        this.ability = true;

        int soundIndex = G_SoundIndex( "sounds/items/quad_pickup" );
        G_Sound( ent, CHAN_ITEM, soundIndex, ATTN_NORM );
        ent.client.inventorySetCount(POWERUP_QUAD, ceil(this.rand));

    }

    void think(Entity @ent) override {
        if (!ability)
        return;
        if (ent.isGhosting())
        return;
        if (this.abilityTimeEnd < levelTime) {
            ability = false;
        }
      }
  };

// Removed in favour of Immortality
/*
class cPowerUpShell : cPowerUp {
    cPowerUpShell() {
        super(
            POWERUPID_SHELL,
            POWERUPRNGTYPE_INTEGER,
            5.0f, 15.0f, false,
            10.0f, 0.0f,
            "WarShell", "Shell",
            S_COLOR_BLUE,
            "You only take in 1/4 of damage for a short amount of time",
            " - %s seconds"
          );
      }

    void select(Entity @ent) override {
        POWERUP_setUpClassaction( @ent, "Activate WarShell");
    }

    void action(Entity @ent, const String &in args = "" ) override {
        this.cooldownTime = levelTime + this.cooldownLength + (this.rand * 1000);
        int soundIndex = G_SoundIndex( "sounds/items/shell_pickup" );
        G_Sound( ent, CHAN_ITEM, soundIndex, ATTN_NORM );
        ent.client.inventorySetCount(POWERUP_SHELL, floor(this.rand));
    }
};*/

class cPowerUpImmortality : cPowerUp {
    cPowerUpImmortality() {
        super(
            POWERUPID_IMMORTALITY,
            POWERUPRNGTYPE_NUMBER,
            2.0f, 5.0f, false,
            10.0f, 10.0f,
            "Immortality", "Immortal",
            S_COLOR_WHITE,
            "You take no damage for %s seconds",
            " - %s seconds"
          );
      }

    float health;
    float armor;

    void select(Entity @ent) override {
        POWERUP_setUpClassaction( @ent, "Activate Immortality");
      }

    void classAction(Entity @ent) override {
        if (!checkCooldown(@ent))
            return;
        // this.abilityLength = (this.rand * 1000);
        this.abilityTimeEnd = levelTime + this.abilityLength;
        this.cooldownTime = levelTime + this.cooldownLength + abilityLength;

        this.ability = true;

        this.health = ent.health;
        this.armor = ent.client.armor;
        ent.client.armor = 0;
        ent.health = 999;

        int soundIndex = G_SoundIndex( "sounds/items/shell_pickup" );
        G_Sound( ent, CHAN_ITEM, soundIndex, ATTN_NORM );
    }

    void think(Entity @ent) override {
        if (!ability)
            return;
        if (ent.isGhosting())
            return;
        if (this.abilityTimeEnd < levelTime) {
            ent.health = this.health;
            ent.client.armor = this.armor;
            ability = false;
            return;
        }
        ent.effects |= EF_GODMODE;
        ent.health = 999;
    }

  };

class cPowerUpPullTowards : cPowerUp {
    cPowerUpPullTowards() {
        super(
            POWERUPID_PULL_TOWARDS,
            POWERUPRNGTYPE_MULTIPLIER,
            1.0f, 2.0f, false,
            0.0f, 0.0f,
            "Pull Towards", "Pull",
            S_COLOR_RED,
            "Enemies get pulled closer to you as you attack them",
            " - %s"
          );
      }

    void dmg(Entity @ent, const String &in args = "" ) override {

        Entity @victim = @G_GetEntity( args.getToken( 0 ).toInt() );
        float damage = args.getToken( 1 ).toFloat();
        if (victim.client == null)
            return;
        if (damage > victim.health + victim.client.armor )
            return;
        if (kb_amount_weapon(ent.weapon) == 0)
            return;
        Vec3 dir, b, c;
        Vec3 angles = ent.angles;
        Vec3 VictimOrigin = victim.origin;
        angles.z += ent.viewHeight;
        angles.angleVectors( dir, b, c );
        dir.x = -dir.x;
        dir.y = -dir.y;
        dir.z = -dir.z;
        VictimOrigin.z += 0.25;
        victim.origin = VictimOrigin;
        victim.sustainDamage( @ent, @ent, dir, 0, kb_amount_weapon(ent.weapon) * this.rand , 0, MOD_BARREL);

      }
  };

class cPowerUpInfiniteAmmo : cPowerUp {
    cPowerUpInfiniteAmmo() {
        super(
            POWERUPID_INFINITE_AMMO,
            POWERUPRNGTYPE_NONE,
            0.0f, 0.0f, false,
            0.0f, 0.0f,
            "Infinite Ammo", "InfAmmo",
            S_COLOR_MAGENTA,
            "You have infinite ammo", ""
          );
      }

    void think(Entity @ent) override {

        // give the weapons and ammo as defined in cvars
        String token, weakammotoken, ammotoken;
        String itemList = g_noclass_inventory.string;
        String ammoCounts = g_class_strong_ammo.string;
        for ( int i = 0; ;i++ )
        {
            token = itemList.getToken( i );
            if ( token.len() == 0 )
                break;                                      // done

            Item @item = @G_GetItemByName( token );
            if ( @item == null )
                continue;

            // if it's ammo, set the ammo count as defined in the cvar
            if ( ( item.type & IT_AMMO ) != 0 )
            {
                token = ammoCounts.getToken( item.tag - AMMO_GUNBLADE );

                if ( token.len() > 0 )
                {
                    ent.client.inventorySetCount( item.tag, token.toInt() );
                }
            }
        }

    }

};


cPowerUp POWERUP_getPowerUpByID(uint id) {
    switch (id)
    {
        case POWERUPID_SWAP:
            return cPowerUpSwap();
        case POWERUPID_INSTA:
            return cPowerUpInsta();
        case POWERUPID_VAMPIRE:
            return cPowerUpVampire();
        case POWERUPID_MAXSPEED:
            return cPowerUpMaxSpeed();
        case POWERUPID_DASH:
            return cPowerUpDashSpeed();
        case POWERUPID_JUMP:
            return cPowerUpJumpSpeed();
        case POWERUPID_EXTRADMG:
            return cPowerUpExtraDamage();
        case POWERUPID_JETPACK:
            return cPowerUpJetpack();
        case POWERUPID_EXTRAKB:
            return cPowerUpExtraKnockback();
        case POWERUPID_LAUNCH:
            return cPowerUpLaunch();
        case POWERUPID_INVISIBILITY:
            return cPowerUpInvisibility();
        case POWERUPID_QUAD:
            return cPowerUpQuad();
        // case POWERUPID_SHELL:
        //     return cPowerUpShell();
        case POWERUPID_IMMORTALITY:
            return cPowerUpImmortality();
        case POWERUPID_PULL_TOWARDS:
            return cPowerUpPullTowards();
        case POWERUPID_INFINITE_AMMO:
            return cPowerUpInfiniteAmmo();
        default:
            return cPowerUpNone();
    }
}

void clearPowerupState(Entity @ent) {
    cPowerUp @pwr = @powerUp[ent.playerNum];
    pwr.endRound(@ent);

    GENERIC_ClearQuickMenu( @ent.client );
    POWERUP_applyPowerupByID(@ent, 0);
    ent.client.setHUDStat( STAT_PROGRESS_SELF, 0 );
    ent.client.pmoveFeatures = PMFEAT_DEFAULT;
    ent.svflags &= ~SVF_ONLYTEAM;
    ent.client.pmoveDashSpeed = -1;
    ent.client.pmoveMaxSpeed  = -1;
    ent.client.pmoveJumpSpeed = -1;
    ent.maxHealth = 100;
};

// utils
void POWERUP_setUpClassaction( Entity @ent, String infotext, String command = "classaction1") {
    GENERIC_SetQuickMenu( @ent.client, "\""+infotext+"\" \""+command+"\"" );
};

void POWERUP_applyRandomPowerup(Entity @ent) {
    uint id = POWERUPS_randomInteger( 1, maxPowerupID);
    // id = POWERUPID_EXTRADMG;
    // if (ent.playerNum == 0)
        // id = POWERUPID_REVIVAL;
    POWERUP_applyPowerupByID(@ent, id);
}
void POWERUP_applyPowerupByID(Entity @ent, uint id) {
    @powerUp[ent.playerNum] = @POWERUP_getPowerUpByID(id);

    if (powerUp[ent.playerNum] != null) {
        powerUp[ent.playerNum].init(ent);
        powerUp[ent.playerNum].select(ent);
      }
};



