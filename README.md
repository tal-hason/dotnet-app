# How to Work in the workshop

to initialize the enviormnet, run the "init_env.sh"

```Bash
./init_env.sh
```

1. in the script you need to provide the following details:

    a. Git-Hub username
    b. GitHub personal access token
    c. email address
    d. Git-Hub repository URL, Your Forked reposistory
    e. workshop cluster FQDN, you can find it in the workshop portal.
    f. workshop user, your user from the workshop Portal, (i.e. user 25)
    g. workshop Cluster API URL, you can find it in the workshop portal.
    h. workshop Password, you can find it in the workshop portal.

2. after the script run the first time it will create a "env_vars.sh" file with all the details so in case the code space will rest it will remember it.

3. to start a new pipeline and update the cluster, run the start_pipeline.sh file.

```Bash
./start_pipeline.sh
```

no input is needed.
