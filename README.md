# How to Work in the workshop

to initialize the enviormnet, run the "init_env.sh"

```Bash
./init_env.sh
```

1. in the script you need to provide the following details:

    - Git-Hub username
    - GitHub personal access token
    - email address
    - Git-Hub repository URL, Your Forked reposistory
    - workshop cluster FQDN, you can find it in the workshop portal.
    - workshop user, your user from the workshop Portal, (i.e. user 25)
    - workshop Cluster API URL, you can find it in the workshop portal.
    - workshop Password, you can find it in the workshop portal.

2. after the script run the first time it will create a "env_vars.sh" file with all the details so in case the code space will rest it will remember it.

3. to start a new pipeline and update the cluster, run the start_pipeline.sh file.

```Bash
./start_pipeline.sh
```

no input is needed.
