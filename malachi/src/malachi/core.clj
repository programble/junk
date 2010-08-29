(ns malachi.core
  (:use [clojure.contrib.core :only [-?> -?>>]]
        [clojure.contrib.string :only [lower-case split]]
        irclj.irclj
        stupiddb.core))

(defn- re-clause-to-if [s [re bindings body] else]
  `(if-let [[~@bindings] (next (re-find ~re ~s))]
    ~body
    ~else))

(defn- re-clauses-to-ifs [s clauses]
  (when-first [clause clauses]
    (if (and (not (next clauses))
             (= (count clause) 1))
      (first clause)
      (re-clause-to-if s clause (re-clauses-to-ifs s (rest clauses))))))

(defmacro cond-re [s & clauses]
  (re-clauses-to-ifs s (partition 3 3 nil clauses)))

(defn causes [e]
  (lazy-seq
    (when e
      (cons e (causes (.getCause e))))))

(defmacro nilify [exp]
  `(do ~exp nil))

;(defonce acronym-pool (atom {\l ["laugh" "loud"], \o ["out"]}))
(defonce acronym-pool (db-init (str (System/getProperty "user.home") "/.malachi-acronym-pool.db") 30))

(defn get-word-starting-with [c]
    (rand-nth (db-get acronym-pool c ["?"])))

(defn make-acronym [acronym]
  (->> (lower-case acronym)
       (map #(get-word-starting-with %))
       (interpose " ")
       (apply str)))

(defn add-to-acronym-pool [word]
  (let [word (lower-case word)
        start (first word)]
    (when (> (count word) 2)
      (db-assoc acronym-pool start (let [old (db-get acronym-pool start [])]
                                        (if (some #(= % word) old)
                                          old
                                          (conj old  word)))))))

(defonce message-stats (db-init (str (System/getProperty "user.home") "/.malachi-message-stats.db") 30))

(defn increment-user [user words]
  (db-assoc message-stats user (+ (db-get message-stats user 0) words)))

(defn user-percentage [user]
  (let [denominator (apply + (vals (:data @message-stats)))
        numerator (db-get message-stats user)]
    (* (/ (float numerator) (float denominator)) 100.0)))

(defn on-command [command irc nick channel]
  (cond-re command
           #"^ping ?(.+)?" [x] (if x (format "pong %s" x) "pong")
           #"^owner$" [] "curtis"
           #"^echo (.+)" [x] x
           #"^reverse (.+)" [x] (apply str (reverse x))
           #"^acronym ([A-Za-z]+)" [acronym] (make-acronym acronym)
           #"(?i)^what does ([A-Za-z]+) stand for?" [acronym] (make-acronym acronym)
           #"^words (.+)" [user] (if (contains? (:data @message-stats) user)
                                      (format "%s said %d words, which is %2.2f%s of the words I have seen" user (db-get message-stats user) (user-percentage user) "%")
                                      (format "I have not seen any messages by %s" user))
           #"^most active$" [] (let [winner (reduce #(if (> (db-get message-stats %2) (db-get message-stats %1)) %2 %1) (keys (:data @message-stats)))]
                                 (format "The most active user is %s with %d words (%2.2f%s)"
                                         winner (db-get message-stats winner) (user-percentage winner) "%"))
           #"^(idler|least active)$" [_] (let [winner (reduce #(if (< (db-get message-stats %2) (db-get message-stats %1)) %2 %1) (keys (:data @message-stats)))]
                           (format "The least active user is %s with %d words (%2.2f%s)"
                                   winner (db-get message-stats winner) (user-percentage winner) "%"))
           #"^moo" [] "moo"
           #"^smite (.+)" [thing] (nilify (send-action irc channel (format "smites %s" thing)))
           #"^shuffle (.+)" [things] (let [thing-list (split #",\s*" things)]
                                       (->> (shuffle thing-list) (interpose ", ") (apply str)))
           #"^choice (.+)" [things] (let [thing-list (split #",\s*" things)]
                                      (rand-nth thing-list))
           #"^attack (.+)" [thing] (nilify (send-action irc channel (format (rand-nth ["slaps %s" "punches %s" "kicks %s" "sets %s on fire" "pushes %s off a bridge"]) thing)))
           #"^feed (.+)" [who] (nilify (send-action irc channel (format "feeds %s some regurgitated %s" who (rand-nth ["salami" "pasta" "turkey" "chicken" "soup"]))))
           #"(?i)^who are you\??$" [] "I am an IRC bot written in Clojure by Curtis McEnroe using the Irclj library by Anthony Simpson. I am named after Malachi Constant from the book \"Sirens of Titan\" by Kurt Vonnegut."
           #"^list$" [] "ping, owner, echo, acronym, who are you, messages, most active, moo, smite, attack, shuffle, feed, reverse"
           #"^(\d{1,2})d(\d{1,2})$" [num sides] (->> (for [_ (range (read-string num))] (inc (rand-int (read-string sides)))) (interpose " ") (apply str))
           #"(?i)^(you are|you're)" [] "no u"
           #"(?i)^good boy" [] ":)"
           #"(?i)^good girl" [] "What? I'm not a girl!"
           #"^([A-Z]+)\?$" [acronym] (make-acronym acronym)
           (rand-nth ["What?" "Hm?" "I don't understand" "What do you mean?" "What's that?"])))

(defn on-message [{:keys [nick channel message irc]}]
  (increment-user nick (count (split #"\s+" message)))
  (try
    (-?>> (cond-re message
                   #"^malachi[:,]?\s+(.+)" [command] (on-command command irc nick channel)
                   #"(curry|beans)" [_] (nilify (send-action irc channel "farts"))
                   #"cows" [] (nilify (send-message irc channel "moo"))
                   #"^[A-Z !.,?']{7,}$" [] (rand-nth ["The key on the left of 'A', press it." "Caps FTL" "Please stop yelling"])
                   #"(.+)" [text] (doseq [word (split #"[\s,.:?\"!/><()*_[\\]]+" text)] (add-to-acronym-pool word)))
          (format "%s: %s" nick)
          (send-message irc channel))
    (catch Exception e
      (->> (causes e)
           (map #(.getMessage %))
           (remove nil?)
           (last)
           (format "Error: %s")
           (send-message irc channel)))))

(defonce bot
  (connect (create-irc {:name "malachi",
                        :server "onyx.ninthbit.net",
                        :fnmap {:on-message #'on-message}})
           :channels ["#programming" "#bots" "#offtopic" "#fridges"]))

(defonce bot-freenode
  (connect (create-irc {:name "malachi",
                        :server "irc.freenode.net",
                        :fnmap {:on-message #'on-message}})
           :channels ["#()" "#(code)" "#botters"]))
