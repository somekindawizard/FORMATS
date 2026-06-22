import Foundation

private func c(_ s: String) -> Prompt { Prompt(text: s, kind: .creative, theme: .genshin) }

// Genshin prompts are creative-only — story sparks set in Teyvat and its archetypes.
extension PromptLibrary {
    static let genshin: [Prompt] = [
        // Mondstadt
        c("The wind in Mondstadt carries a melody no one has played in a thousand years. Someone finally recognizes it. Write the moment."),
        c("Write a night at the Angel's Share when Diluc and Kaeya are the only two left, and neither will say goodnight first."),
        c("Klee is grounded for a week. Write the elaborate, doomed plan she builds to escape and 'help.'"),
        c("Albedo paints something he hasn't seen yet, and it begins to come true. Continue."),
        c("Write the diary of Dvalin's last calm flight before the storm took him."),
        c("A bard arrives in a town that has outlawed music. Write the first song he risks."),
        c("Jean finds an old letter from her father she was never meant to read. Write what it says and what she does."),
        c("Write a scene where Fischl's 'Oz' answers a question Fischl herself can't."),
        c("Eula plans an elaborate 'vengeance' that turns out to be an act of kindness. Reveal it slowly."),
        c("A knight of Favonius is assigned to guard a single dandelion seed across the whole region. Write the journey."),
        c("Venti trades a song for a secret in a quiet tavern. Write the secret and the price."),
        c("Mona reads a fortune she refuses to say aloud. Write the night she finally tells someone."),

        // Liyue
        c("Zhongli attends his own mock funeral and overhears what people really think of him. Write it."),
        c("Hu Tao guides a spirit who refuses to believe it has died. Write their walk to the harbor."),
        c("Write the night Xiao stands guard over a sleeping city and is, for once, thanked."),
        c("A merchant in Liyue sells 'bottled luck.' One bottle is real. Write what happens when it's opened."),
        c("Ganyu falls asleep mid-shift and wakes to find the work done by someone who left no name. Continue."),
        c("Write the story of a contract signed in a teahouse that binds two enemies to save each other once."),
        c("Madame Ping closes her shop, brews tea, and tells a child the true story of how the mountains were made. Write the story she tells."),
        c("Madame Ping plants a tree that won't bloom for three hundred years and writes a note for whoever sees it flower. Write the note."),
        c("Ningguang plays a game of stones with a rival where every move is a real decision about the city. Write the final move."),
        c("Write a Lantern Rite where one lantern, when lit, shows the wisher their own future. Whose is it?"),
        c("Xiangling invents a dish that makes the eater remember their happiest meal. Write a stranger's reaction."),
        c("Childe and Zhongli share one quiet meal with everything unsaid between them. Write the dinner."),

        // Inazuma
        c("Write the moment the Raiden Shogun, deep in her Plane of Euthymia, is visited by the one memory she tried to delete."),
        c("Kazuha hears the 'unheard words' of a dying tree and must decide whether to share them. Write it."),
        c("A festival in Inazuma is interrupted when the fireworks spell out a warning. Write the night."),
        c("Write a quiet scene where Ayaka teaches a frightened child the tea ceremony during a storm."),
        c("Yae Miko offers a desperate writer a contract: a perfect story, in exchange for one memory. Write the negotiation."),
        c("Two rival swordsmen are trapped by a typhoon and must share a single lantern's worth of oil and truth. Continue."),
        c("Write the legend of the lightning that struck the same shrine for a hundred years, and what it was guarding."),
        c("Thoma is asked to make one impossible person feel at home. Write his first, failed attempt and his second, better one."),
        c("Yoimiya promises a dying festival one last unforgettable night. Write how she keeps the promise."),

        // Sumeru
        c("Nahida shows a grieving stranger a dream of the person they lost. Write what the dream gets wrong, and right."),
        c("Write a debate in the Akademiya where the losing side is, quietly, correct. Reveal it at the end."),
        c("In the rainforest, a researcher discovers a plant that records sound. Play back the oldest thing it heard."),
        c("The Wanderer revisits the place he was created and finds someone living there now. Write the meeting."),
        c("Write the story of a scribe in the House of Daena who finds a book that is writing itself, in his own hand."),
        c("Cyno tells a joke so bad it accidentally breaks a curse. Write the scene around it."),
        c("A desert village shares one well and one secret. A traveler is offered both. Continue."),
        c("Write the night Collei finally sleeps without nightmares, and the small thing that made it possible."),
        c("Alhaitham agrees to help solve a problem only if no one thanks him for it. Write why."),

        // Fontaine
        c("Write the trial of a clockwork servant accused of feeling, with Neuvillette presiding."),
        c("Furina, no longer a god, takes a job at a tiny cafe and serves a customer who recognizes her. Write it."),
        c("Lyney performs a trick that requires the audience to trust a stranger completely. Write the moment of trust."),
        c("Write a scene in the deep underwater prison where the most dangerous inmate tends a garden of glowing fungus."),
        c("The waters of Fontaine begin to rise in a single house. The family inside decides to stay. Why?"),
        c("Navia hosts a gathering where everyone must bring the thing they're most afraid to lose. Write what one guest brings."),
        c("Write the story of a detective in Fontaine solving the case of a memory that doesn't belong to anyone."),
        c("Sigewinne treats a patient whose only ailment is a broken promise. Write the cure."),
        c("Wriothesley grants one prisoner a single afternoon of sunlight. Write the afternoon."),

        // Natlan
        c("Write the first ride of a young dragon and its rider, neither of whom is sure of the other."),
        c("In Natlan, the dead are spoken to before a great battle. Write one such conversation."),
        c("Mavuika leads a people toward a war they may lose, and lights one fire that will outlast them all. Write the lighting."),
        c("A surfer in Natlan rides a wave that carries her into a memory of the ocean's past. Continue."),
        c("Write the legend of the night the volcano spoke, and the one person who answered."),
        c("Kachina is given a task far too big for her. Write the moment she decides to try anyway."),
        c("Two tribes settle an ancient grudge with a single game. Write the final round."),
        c("Citlali passes down one last piece of forbidden knowledge before the season turns. Write the lesson."),

        // Fatui / Snezhnaya / Khaenri'ah
        c("Write a morning in the House of the Hearth, where Arlecchino's 'children' make her breakfast and she lets them think she doesn't notice."),
        c("Childe spars with someone who refuses to fight back, and it unsettles him more than any battle. Write it."),
        c("Capitano keeps a promise to a fallen enemy across a whole campaign. Reveal the promise at the end."),
        c("Write the quiet hour before a Harbinger betrays the cause, told from their point of view."),
        c("Dainsleif walks through the ruins of Khaenri'ah and tells the empty streets the news of the world. Write his report."),
        c("A Fatui agent is ordered to steal something that turns out to be a child's drawing. Write the theft and the change of heart."),
        c("Write the story of the Knave teaching an orphan that love and survival are not opposites."),
        c("Columbina hums a tune that makes everyone who hears it tell the truth. Write what spills out."),

        // Cross-Teyvat / archetype sparks
        c("A Traveler arrives in a region not on any map, where the people have never heard of the Seven. Write the first hour."),
        c("Write a tavern at the crossroads of all seven nations, on the one night a year their travelers all meet."),
        c("A Vision goes dark and its bearer must learn who they are without their element. Continue."),
        c("Write the story of the unseen god of a forgotten eighth element, and the single believer who remembers them."),
        c("Paimon goes missing and the Traveler must navigate a whole region alone for the first time. Write the loneliness."),
        c("A wish made at a Statue of the Seven is granted too literally. Write the consequence."),
        c("Write the legend of the first person to receive a Vision, before anyone knew what it meant."),
        c("Two enemies from rival nations are stranded in a domain together and must clear it as a team. Begin."),
        c("A cartographer sets out to map the entire world and writes a final entry that changes everything. Write it."),
        c("Write the day the Abyss sends not a monster but a letter, addressed to a single ordinary person."),
        c("A teapot replica of a home grows, overnight, a room no one built. Write who lives in it."),
        c("Write the story of an adventurer who completes their last commission and must decide what a life without quests looks like."),
        c("The seven Archons meet in secret once a century. Write the part of the meeting no mortal was meant to hear."),
        c("A child in a small village receives a Vision and the whole town must decide what it means for them. Continue."),
        c("Write a scene where a forgotten ruin reactivates and offers its visitor a choice between knowledge and peace."),
        c("Two travelers who have never met have been leaving each other notes in the same wayside shrine for years. Write the day they finally overlap."),
        c("A Fatui delegation and a Liyue merchant negotiate a deal that hinges on a single shared meal. Write the dinner."),
        c("Write the story of a 'leyline outflow' that, when cleared, releases not energy but a person's lost memory."),
        c("An old adventurer trains a young one and, in the last lesson, admits the real reason they kept fighting. Write the lesson."),
        c("Write the founding myth of a nation that worships no Archon, only the wind that connects them all."),
        c("A character finds a Wish in physical form and learns that to use it, they must give it a true name. Continue."),
        c("Write the night the stars over Teyvat rearrange themselves, and the one astronomer brave enough to read the new sky."),
        c("A domain remembers the last person who cleared it and refuses to let the next one leave until they hear the story. Write it.")
    ]
}
